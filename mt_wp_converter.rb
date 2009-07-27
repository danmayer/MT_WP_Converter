require 'fileutils'
require 'pathname'
require 'ruby-debug'

class Mt_wp_converter

  def initialize(filename)
    @filename = filename
    @domain = "erinashleymiller.com"
    @file_root = "http://#{@domain}/files/2009/07/"
  end

  def convert
    content = File.read(@filename)
    old_content = content
    new_content = content

    matches = []
    regex = /http:\/\/(|www\.)#{domain}([A-Z]|[a-z]|[0-9]|\s|\/|_|-|%|$|#)*\.(JPG|jpg)/

    while old_content.match(regex)
      path = old_content.match(regex).to_s
      matches << path
      old_content = old_content.gsub(path,'')
    end

    matches.each do |m|
      path = Pathname.new(m)
      filename = path.basename.to_s
      #wordpress doesn't use ' ' or %$s in its image files
      filename_new = filename.gsub(" ","-")
      filename_new = filename_new.gsub(/%20/,"-")
      new_content = new_content.gsub(m,"#{@file_root}/#{filename_new.downcase}")
    end

    #fixing weird MT conversion or exporting errors mapping the error codes back to characters
    new_content = new_content.gsub(/\351/,"&egrave;")
    new_content = new_content.gsub(/\226/,"-")
    new_content = new_content.gsub(/\264/,"&rsquo;")
    new_content = new_content.gsub(/\361/,"&ntilde;")
    new_content = new_content.gsub(/\362/,"&oacute;")
    new_content = new_content.gsub(/\354/,"&iacute;")
    new_content = new_content.gsub(/\340/,"&aacute;")
    new_content = new_content.gsub(/\350/,"&eacute;")
    new_content = new_content.gsub(/\303\262/,"&oacute;")
    new_content = new_content.gsub(/\303\240/,"&aacute;")

    File.open('converted.txt', 'w') do |f|
      f.write(new_content)
    end
  end
  
end



#Takes in a filename to convert from the cmd line
filename = ARGV.shift

converter = Mt_wp_converter.new(filename)
converter.convert
