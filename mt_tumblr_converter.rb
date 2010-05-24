require 'fileutils'
require 'pathname'
require 'ruby-debug'
require 'ostruct'
require 'rest_client'
require 'json'

# multiple gems use the require tumblr, this one refers to http://github.com/mwunsch/tumblr
# note that ruby-debug and the weary lib, which makes reqs for this tumblr gem, don't play nicely together
require 'tumblr'

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
    @tumblr = Tumblr.new(user, pass)
    @tumblr_uri = tumblr_uri
    @disqus_shortname = disqus_shortname
    @disqus_user_api_key = disqus_user_api_key
    @error_count = 0
  end

  def convert
    content = File.read(@filename)

    # extract posts information
    entries = content.split("--------\n")
    puts "found and parsing #{entries.length}"
    entries.each do |entry|
      begin
        mt_entry = extract_entry(entry)
        comments = extract_comments(entry)
        unless has_exclude_categories(mt_entry.categories)
          post_url, post_title = post_to_tumblr({:categories => mt_entry.categories.join(","), :date => mt_entry.date, :body => mt_entry.body, :title => mt_entry.title})
          puts mt_entry.title
          post_comments_to_disqus(post_url, post_title, comments)
        end
      rescue => error
        puts "an error occured parsing this entry, error: #{error}"
        puts entry
        puts error.inspect
        @error_count += 1
      end
    end
    puts "A total of #{@error_count} errors occured the posts with errors are printed above"
  end

  def extract_entry(entry)
    author = entry.match(/AUTHOR: (.*)/)[1]
    title = entry.match(/TITLE: (.*)/)[1]
    categories = entry.scan(/CATEGORY: (.*)/).flatten.uniq
    date = entry.match(/DATE: (.*)/)[1]
    body = entry.split("-----\n")[1].sub("BODY:",'')
    if entry.split("-----\n")[2]
      ext_body = entry.split("-----\n")[2].sub("EXTENDED BODY:",'').strip
      body += ext_body if ext_body.length > 0
    end
    OpenStruct.new(:author => author, :categories => categories, :date => date, :body => body, :title => title)
  end

  def extract_comments(entry)
    comments = []
    entry_peices = entry.split("-----\n")
    entry_peices.each_with_index do |peice, index|
      #the comments start at entry[5] and go until there are no more items. a < length loop should be able to get all comments, but 
      unless(index<5)
        if peice.strip.length!=0
          comment_author = peice.match(/AUTHOR: (.*)/)[1]
          comment_email =  peice.match(/EMAIL: (.*)/)[1]
          comment_date = peice.match(/DATE: (.*)/)[1]
          comment_url = peice.match(/URL: (.*)/)[1]
          comment_body = peice.to_a[6...peice.to_a.length].join('')
          comments << {:author => comment_author, :email => comment_email, :date => comment_date, :url => comment_url, :body => comment_body}
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
    #TODO just do a options merge
    post_result = @tumblr.post({:type => :regular, :title => options[:title], :body => options[:body], :date => options[:date], :tags => options[:categories]}).perform
    read_result = @tumblr.read(@tumblr_uri, {:id => post_result.to_s}).perform
    url = read_result.parse['tumblr']['posts']['post']['url_with_slug']
    title = read_result.parse['tumblr']['posts']['post']['slug']
    return [url, title]
  end

  #mostly from http://github.com/squeejee/disqus-sinatra-importer/blob/master/import.rb
  def post_comments_to_disqus(url, title, comments)
    disqus_url = 'http://disqus.com/api'
    resource = RestClient::Resource.new disqus_url

    forums = JSON.parse(resource['/get_forum_list?user_api_key='+@disqus_user_api_key].get)
    forum_id = forums["message"].select {|forum| forum["shortname"]==@disqus_shortname}[0]["id"]
    forum_api_key = JSON.parse(resource['/get_forum_api_key?user_api_key='+@disqus_user_api_key+'&forum_id='+forum_id].get)["message"]

    thread = JSON.parse(resource['/get_thread_by_url?forum_api_key='+forum_api_key+'&url='+url].get)["message"]

    # If a Disqus thread is not found with the current url, create a new thread and add the url.
    if thread.nil?  
      thread = JSON.parse(resource['/thread_by_identifier/'].post(:forum_api_key => forum_api_key, :identifier => title, :title => title))["message"]["thread"]
      # Update the Disqus thread with the current article url
      resource['/update_thread/'].post(:forum_api_key => forum_api_key, :thread_id => thread["id"], :url => url) 
    end
    
    # Import posts here
    comments.each do |comment|
      begin
        #format comment correctly for disqus
        convert_date = Time.parse(comment[:date]).strftime("%Y-%m-%dT%H:%M")
        post = resource['/create_post/'].post(:forum_api_key => forum_api_key,
                                              :thread_id => thread["id"],
                                              :message => comment[:body],
                                              :author_name => comment[:author],
                                              :author_email => comment[:email],
                                              :created_at => convert_date)
      rescue => error
        puts "error importing comment: #{error}, comment: #{comment}"
      end
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
converter.convert
