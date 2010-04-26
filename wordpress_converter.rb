require 'fileutils'
require 'pathname'
require 'ruby-debug'
require 'hpricot'
require 'open-uri'

class WordpressConverter

  def initialize(filename)
    @filename = filename
    @domain = "devver.wordpress.com"
    @file_root = "http://#{@domain}/files/2009/07/"
  end

  def raw_code(url)
    doc = Hpricot(open(url)) 
    raw_url = 'http://gist.github.com'+doc.search('a[text()="raw"]').first['href']
    raw_code = open(raw_url).read
  end

  def convert
    content = File.read(@filename)
    old_content = content
    new_content = content

#     wordpress can automatically get all images and blog attachments now.
#     replace the image URI with new URIs
#     matches = []
#     regex = /http:\/\/(|www\.)#{domain}([A-Z]|[a-z]|[0-9]|\s|\/|_|-|%|$|#)*\.(JPG|jpg)/

#     while old_content.match(regex)
#       path = old_content.match(regex).to_s
#       matches << path
#       old_content = old_content.gsub(path,'')
#     end

#     matches.each do |m|
#       path = Pathname.new(m)
#       filename = path.basename.to_s
#       #wordpress doesn't use ' ' or %$s in its image files
#       filename_new = filename.gsub(" ","-")
#       filename_new = filename_new.gsub(/%20/,"-")
#       new_content = new_content.gsub(m,"#{@file_root}/#{filename_new.downcase}")
#     end

    #fixing code blocks
    new_content = new_content.gsub(/\[ruby\]/,'[sourcecode language="ruby"]')
    new_content = new_content.gsub(/\[\/ruby\]/,"[/sourcecode]")
    new_content = new_content.gsub(/<code>/,'[sourcecode language="ruby"]')
    new_content = new_content.gsub(/<\/code>/,"[/sourcecode]")
    new_content = new_content.gsub(/\[plain\]/,"<pre>")
    new_content = new_content.gsub(/\[\/plain\]/,"</pre>")

    #find gist embeds and link them
    gists = old_content.scan(/<script src="http:\/\/gist\.github\.com.*?<\/script>/)
    gists.each do |gist|
      gist_link = gist.match(/http.*[0-9]+/).to_s
      raw_gist = raw_code(gist_link)
      raw_gist = "[sourcecode language='ruby']#{raw_gist}[/sourcecode]"
      new_content = new_content.gsub(gist,"#{raw_gist}<br/><a href='#{gist_link}'>view this gist</a>")
    end

    File.open('converted.xml', 'w') do |f|
      f.write(new_content)
    end
  end
  
end



#Takes in a filename to convert from the cmd line
filename = ARGV.shift

converter = WordpressConverter.new(filename)
converter.convert
