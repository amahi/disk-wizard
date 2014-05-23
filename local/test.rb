#! /usr/local/bin/ruby
=begin
result = `lsblk -b -P -o MODEL,TYPE,SIZE,KNAME,MOUNTPOINT,FSTYPE`.each_line

result.each do |line|
	data_hash = {}	
	line_data = line.gsub(/"/, '').split " "
	for data in line_data
		key_value_pairs = data.split "="
		data_hash[key_value_pairs[0]] = key_value_pairs[1]
	end
	puts data_hash
	blkid_result = `df -T /dev/#{data_hash['KNAME']}`.lines.pop
	puts blkid_result.gsub(/"/, '') unless blkid_result.empty?
end	
=end

class A
	def initialize command
		@c = command
	end

	def mk e
		@e = e
	end

	def p
		puts "This is c = #{@c}"
		puts "This is e = #{@e}"
	end

end

a = A.new "cccccccccc"
a.p rescue puts "error"
a.mk "eeeeeeeee"
a.p
