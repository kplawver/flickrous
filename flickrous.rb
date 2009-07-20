require 'typhoeus'
require 'json/ext'

## If you know which flickr method you want to call and I haven't added it yet, you can use Flickr.api_call - just pass in the method name, and a hash of the other parameters you want to set.  It will return the Hash from the JSON response.
# 
# Here's what we've got so far:
#
# Flickr.tag_search(tag,perpage,page)
#  - Returns a FlickrPhotoResult (methods are - page, pages, perpage, total, and photos)
#  - .photos is an array of FlickrPhoto objects.  Any key that comes back from Flickr is available as a method (or should be)
#
# Flickr.tag_clusters(tag)
#   - Returns a FlickrTagClusterSet object.  Methods are: tag, clusters. clusters is an array of FlickrTagCluster objects
#   - FlickrTagCluster objects have the following methods: tag, cluster (an array of tags) and photos, which pulls the photos for that cluster. It DOESN'T support pagination so you get 100 photos every time.



class Flickrous
	include Typhoeus
	# Your API Key goes here:
	@@api_key = ""
	# Your API Secret goes here (I haven't added any auth stuff yet, but may in the future):
	@@api_secret = ""
	
	remote_defaults :on_success => lambda {|response| JSON.parse(response.body)},
		:base_uri => "http://api.flickr.com"
	define_remote_method :rest, :path => "/services/rest/"
	
	def self.api_key
		@@api_key
	end
	
	def self.api_key=(key)
		@@api_key = key
	end
	
	def self.api_secret
		@@api_secret
	end
	
	def self.api_secret=(key)
		@@api_secret = key
	end
	
	def self.api_call(method,params)
		params[:method] = method
		params[:api_key] = self.api_key
		params[:format] = "json"
		params[:nojsoncallback] = 1
		self.rest(:params => params)
	end
	
	def self.tag_search(tags,perpage=20,page=1)
		if tags.class == String
			t = tags
		else
			t = tags.join(",")
		end
		result = self.api_call("flickr.photos.search",{:tags => t, :license => "4,7", :safe_search => 2, :content_type => 1,:extras => "owner_name,license,date_taken,icon_server,url_sq,url_t,url_s,url_m", :per_page => perpage, :page => page})
		FlickrPhotoResult.new(result)
	end
	
	def self.tag_clusters(tag)
		FlickrTagClusterSet.new(tag,self.api_call("flickr.tags.getClusters",{:tag => tag}))
	end
	
	def self.cluster_photos(tag,cluster_tags,perpage=20,page=1)
		r = self.api_call("flickr.tags.getClusterPhotos",{:tag => tag, :cluster_id => cluster_tags.join('-'), :per_page => perpage, :page => page, :safe_search => 2, :content_type => 1, :license => "4,7", :extras => "owner_name,license,date_taken,icon_server,url_sq,url_t,url_s,url_m"})
		FlickrPhotoResult.new(r)
	end

	class FlickrTagClusterSet
		attr_accessor :tag, :clusters
		
		def initialize(tag,result)
			self.tag = tag
			self.clusters = []
			if result['clusters']['cluster']
				result['clusters']['cluster'].each do |c|
					self.clusters << FlickrTagCluster.new(tag,c)
				end
			end
		end
		
		def to_json(*a)
			{:tag => self.tag, :clusters => self.clusters}.to_json
		end
		
	end

	class FlickrTagCluster
		attr_accessor :tag, :cluster
		
		def initialize(tag,result)
			self.tag = tag
			self.cluster = []
			result['tag'].each do |t|
				self.cluster << t['_content']
			end
		end
		
		def photos
			Flickr.cluster_photos(self.tag,self.cluster)
		end
		
		def to_json(*a)
			{:tag => self.tag, :cluster => self.cluster}.to_json
		end
		
	end

	class FlickrPhotoResult
		attr_accessor :perpage, :total, :pages, :page, :photos
		def initialize(result)
			self.photos = []
			self.perpage = 0
			self.total = 0
			self.pages = 0
			self.page = 0
			
			if result['photos']
				self.perpage = result['photos']['perpage'] || 0
				self.total = result['photos']['total'] || 0
				self.pages = result['photos']['pages'] || 0
				self.page = result['photos']['page'] || 0
			end
			if result['photos']['photo']
				result['photos']['photo'].each do |p|
					self.photos << FlickrPhoto.new(p)
				end
			end
		end
		
		def random
			self.photos[rand(self.photos.length)-1]
		end
		
		def to_json(*a)
			{:perpage => self.perpage, :total => self.total, :pages => self.pages, :page => self.page, :photos => self.photos}
		end
		
		
	end

	class FlickrPhoto
		attr_accessor :result_hash
		def initialize(r)
			self.result_hash = r
		end
		
		def id
			self.result_hash['id']
		end
		
		def method_missing(m,*a)
	      if self.result_hash.include?(m.to_s)
	        return self.result_hash[m.to_s]
	      else
	        nil
	      end
		end
		
		def photo_page
			"http://www.flickr.com/photos/#{self.owner}/#{self.id}"
		end
		
		def to_json(*a)
			self.result_hash.to_json
		end
	end
	
end