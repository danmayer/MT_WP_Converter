require 'fileutils'
require 'pathname'
require 'ruby-debug'
require 'ostruct'

#multiple gems use the require tumblr, this one refers to http://github.com/mwunsch/tumblr
#note that ruby-debug and the weary lib which makes posts for this tumblr gem don't play nicely together
require 'tumblr'
 
class Mt_tumblr_converter

  EXCLUDED_CATEGORIES = ['Computer Science', 'Ruby', 'Machine Learning', 'Resources', 'Ruby on Rails']
  TUMBLR_BLOG_URI = 'danmayer' # ie danmayer.tumblr.com

  def initialize(filename, user, pass)
    @filename = filename
    @tumblr = Tumblr.new(user, pass)
    @error_count = 0
  end

  def convert
    content = File.read(@filename)

    # extract posts information
    entries = content.split("--------\n")
    puts "found and parsing #{entries.length}"
    entries.each do |entry|
      begin
        author = entry.match(/AUTHOR: (.*)/)[1]
        title = entry.match(/TITLE: (.*)/)[1]
        categories = entry.scan(/CATEGORY: (.*)/).flatten.uniq
        date = entry.match(/DATE: (.*)/)[1]
        body = entry.split("-----\n")[1].sub("BODY:",'')
        if entry.split("-----\n")[2]
          ext_body = entry.split("-----\n")[2].sub("EXTENDED BODY:",'').strip
          body += ext_body if ext_body.length > 0
        end
        comments = extract_comments(entry)
        unless has_exclude_categories(categories)
          post_url = post_to_tumblr({:categories => categories.join(","), :date => date, :body => body, :title => title})
          exit
        end
      rescue => e
        puts "an error occured parsing this entry, error: #{e}"
        @error_count += 1
        puts entry
      end
    end
    puts @error_count
  end

def extract_comments(entry)
  comments = []
  entry_peices = entry.split("-----\n")
  entry_peices.each_with_index do |peice, index|
    #the comments start at entry[5] and go until there are no more items. a < length loop should be able to get all comments, but 
    unless(index<5)
      if peice.strip.length!=0
        comment_author = peice.match(/AUTHOR: (.*)/)[1]
        comment_date = peice.match(/DATE: (.*)/)[1]
        comment_url = peice.match(/URL: (.*)/)[1]
        comment_body = peice.to_a[6...peice.to_a.length].join('')
        comments << {:author => comment_author, :date => comment_date, :url => comment_url, :body => comment_body}
      end
    end
  end
  comments
end

  def has_exclude_categories(categories)
    categories.each do |category|
      return true if EXCLUDED_CATEGORIES.include?(category)
    end
    return false
  end

  def post_to_tumblr(options)
    #just do a options merge
    post_result = @tumblr.post({:type => :regular, :title => options[:title], :body => options[:body], :date => options[:date], :tags => options[:categories]}).perform
    read_result = @tumblr.read(TUMBLR_BLOG_URI, {:id => post_result.to_s}).perform
    read_result.parse['tumblr']['posts']['post']['url_with_slug']
  end
  
end



#Takes in a filename to convert from the cmd line
filename = ARGV.shift
user = ARGV.shift #tumblr email login
pass = ARGV.shift #tumblr pass

converter = Mt_tumblr_converter.new(filename, user, pass)
converter.convert
