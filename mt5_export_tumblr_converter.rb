require "rubygems"
require 'fileutils'
require 'pathname'
require 'ruby-debug'
require 'ostruct'
require 'rest_client'
require 'json'
require 'active_support'
require 'time'
require 'nokogiri'

# multiple gems use the require tumblr, this one refers to http://github.com/mwunsch/tumblr
# note that ruby-debug and the weary lib, which makes reqs for this tumblr gem, don't play nicely together
#require 'tumblr'
require 'tumblr'

###################
#
#  Currently it looks like some html needs to be unescapes or escapes to get to tumblr correctly.
#  Possibly fix broken images and bring them over from the server as well.
#
#  Needs a reset helper method that will delete all posts so I can reimport and try again
###################


#########
# Author: Dan Mayer
# This script helps import a movable type exported blog into tumblr and the associated disqus comment system (all posts and comments should successfully be ported).
# usage: `ruby mt_tumblr_converter.rb exported_blog_file.txt your@email.com your_password tumblr_blog_uri disqus_shortname`
# tumblr_blog_uri: danmayer for danmayer.tumblr.com (even if you have a custom domain you have a tumblr uri)
# disqus_shortname: http://help.disqus.com/entries/103511-what-is-my-site-shortname
# disqus_user_api_key: found here http://disqus.com/api/get_my_key/
#########
class Mt_tumblr_converter

  # exclude any post that includes these categories, I am only porting non CS posts to my new blog
  EXCLUDED_CATEGORIES = ['Computer Science', 'Ruby', 'Machine Learning', 'Resources', 'Ruby on Rails']

  def initialize(filename, user, pass, tumblr_uri, disqus_shortname, disqus_user_api_key)
    @filename = filename
    # @tumblr = Tumblr.new(user, pass)
    @tumblr_user = Tumblr::User.new(user, pass)
    @tumblr_uri = tumblr_uri
    @disqus_shortname = disqus_shortname
    @disqus_user_api_key = disqus_user_api_key
    @error_count = 0
  end

  def author_name(author_id)
    author_id==2 ? 'Dom' : 'Nicole'
  end

  # This sort of works, but it doesn't always delete saying there are rights issues
  # 403: User cannot edit this post.
  def delete_all
    Tumblr.blog = 'mymovetola'
    errors = 0
    @posts = Tumblr::Post.all
    @posts.each do |post|
      #puts post['id']
      #debugger
      begin
        Tumblr::Post.destroy(@tumblr_user, :post_id => post['id'])
        sleep 3
      rescue => e
        puts e
        errors += 1
      end
    end
    puts "there were errors: #{errors}"
  end

  def convert
    content = File.read(@filename)
    doc = Nokogiri::XML(content)

    missing = 0
    continue = false
    doc.root.children.select{|e| e.name=='entry'}.each do |node|
      #puts " - #{ node['authored_on'] } ( #{ node['title'] }: #{ node.text })"
      date = Time.parse(node['authored_on'])
      #date = date.strftime("%Y-%m-%d")
      title = node['title']
      unless title
        missing+=1
        title = "no title #{missing}"
      end
      title_url = title.gsub(' ','-').gsub(/(!|:|\/|\.|\+|\?|#|\(|\))/,'')
      author = author_name(node['author_id'])
      body = node.text
      post_data = {:author => author, :categories => nil, :date => date, :body => body, :title => title}
      continue = true if title=='Rainbow over Hollywood'
      if continue
        puts title
        post_to_tumblr(post_data)
        sleep 3.0      #don't exceed the api rate limit
      end
    end
    puts "missing: #{missing}"
  end

  def post_to_tumblr(options)
    post = Tumblr::Post.create(@tumblr_user, :type => 'regular', :title => options[:title], :body => options[:body], :date => options[:date])
  end

end

#patch the tumblr api gem, for it's post bug, it was using :query opposed to :body for posting
class Tumblr
  class Request

    # a POST request to http://www.tumblr.com/api/write
    def self.write(options = {})
      response = HTTParty.post('http://www.tumblr.com/api/write', :body => options)
      return(response) unless raise_errors(response)
    end
  end
end


#Takes in a filename to convert from the cmd line
filename = ARGV.shift
user = ARGV.shift #tumblr email login
pass = ARGV.shift #tumblr pass
tumblr_uri = ARGV.shift
disqus_shortname = ARGV.shift
disqus_user_api_key = ARGV.shift

converter = Mt_tumblr_converter.new(filename, user, pass, tumblr_uri, disqus_shortname, disqus_user_api_key)
#converter.convert
converter.delete_all
