# lenovo-password - Implementation of Lenovo ThinkPad HDD password algorithm
# Copyright (C) 2015  Jethro G. Beekman
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

require 'digest/sha2'
require 'optparse'
require 'io/console'

### DEBUG FUNCTIONS ###
def debug_dump(s)
	#puts " "+s.chars.to_a*"  "
	#puts s.unpack('H*')[0].chars.each_slice(2).map{|v|v*""}*" "
	#puts "-------"
	s
end

### HDPARM INPUT FUNCTIONS ###
def lb(w)
	w&0xff
end

def hb(w)
	w>>8
end

def usable_for_endianness_check?(w,val)
	(lb(w)==val) != (hb(w)==val)
end

def swap_endianness!(identify)
	identify.replace(identify.pack('v*').unpack('n*'))
end

def read_hdparm(file,endianness=:detect)
	identify=IO.read(file).split.select{|s|s=~/^\h{4}$/}.map{|v|[v].pack('H*').unpack('S')[0]}
	raise "File does not contain an ATA IDENTIFY block" if identify.count!=256
	if endianness==:machine then
	elsif endianness==:reverse then
		swap_endianness!(identify)
	else
		if usable_for_endianness_check?(identify[47],0x80) then
			swap_endianness!(identify) if hb(identify[47])!=0x80
		elsif usable_for_endianness_check?(identify[255],0xa5) then
			swap_endianness!(identify) if lb(identify[47])!=0xa5
		else
			sn=identify[10...20].pack("n*")
			mn=identify[27...47].pack("n*")
			raise "Unable to identify endianness of ATA IDENTIFY block.\nIf the following strings look correct, use --machine.\nIf they should be character-swapped, use --reverse.\nSerial number: <#{sn}>\nModel number: <#{mn}>"
		end
	end
	return identify
end

### LENOVO-SPECIFIC FUNCTIONS ###
def _lenovo__translate_password(pwd)
	pwd.force_encoding('binary')
	pwd.gsub!(/[^1234567890qwertyuiopasdfghjkl;zxcvbnm ]/i,'')
	pwd.downcase.tr('1234567890qwertyuiopasdfghjkl;zxcvbnm ',[2..11,16..25,30..39,44..50,57..57].map{|r|r.map{|i|i.chr}*""}*"").ljust(64,0.chr)
end

def _lenovo__get_model_sn(ata_identify_block)
	ata_identify_block.values_at(10...20,27...47).pack('v*')
end

def _lenovo__truncate_hash(hash)
	hash[0...12]
end

def _lenovo__hash_password(password,ata_identify_block)
	debug_dump(
		Digest::SHA256.digest(debug_dump(
			_lenovo__truncate_hash(debug_dump(
				Digest::SHA256.digest(debug_dump(
					_lenovo__translate_password(debug_dump(password))
				))
			))+
			_lenovo__get_model_sn(ata_identify_block)
		))
	)
end

### I/O FUNCTIONS ###
def get_password
	if $stdin.isatty then
		$stderr.print "Enter password: "
		ret=$stdin.noecho(&:gets).chomp
		$stderr.print "\n"
	else
		ret=$stdin.gets.chomp
	end
	return ret
end

### MAIN ###
endianness=:detect
hex=false

begin
	### PARSE COMMAND LINE OPTIONS ###
	optparse=OptionParser.new do |opts|
		opts.banner = "Usage: pw.rb [options] ata_identify_file"
		opts.on('-h','--hex',    'Output password hash in hexadecimal form') {hex=true}
		opts.on(nil ,'--machine','Force native endianness'                 ) {endianness=:machine}
		opts.on(nil ,'--reverse','Force reverse endianness'                ) {endianness=:reverse}
	end

	optparse_exit=proc do
		$stderr.puts optparse
		exit(1)
	end

	begin
		optparse.parse!
	rescue OptionParser::ParseError => e
		$stderr.puts e.message
		optparse_exit.call
	end

	optparse_exit.call if ARGV.count!=1

	hdid_file=ARGV[0]
end

begin
	### INPUT ###
	hdparm=read_hdparm(hdid_file,endianness)
	password=get_password()
	### COMPUTE ###
	digest=_lenovo__hash_password(password,hdparm)
	### OUTPUT ###
	$stderr.puts "Warning: digest includes NULL-character (unsupported by hdparm versions before 9.46)!" if digest.include?(0.chr)
	print hex ? "hex:#{digest.unpack("H*")[0]}\n" : digest
rescue Exception => e
	### ERROR ###
	$stderr.puts "Caught exception: #{e.class}:\n#{e}"
	exit(1)
end
