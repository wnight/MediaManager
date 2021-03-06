#!/usr/bin/ruby
#Read configuration file

#For testing purposes, the home directory must be dynamically determined
#to allow for testing to be done on Apple computers who's users' home dirs
#are in /Users/
$mmconfig = "#{`cd ~;pwd`.chomp}/Documents/Projects/MediaManager/MediaManager.config"
raise "Cannot read config file!!!" unless load $mmconfig

#Initialize the cache and blacklist arrays
$TVDB_CACHE||={}
$IMDB_CACHE||={}
$IMDB_BLACKLIST=[]

#This is so that we can require files in the same directory without the .rb extention.
$LOAD_PATH << File.expand_path(File.dirname(__FILE__))

#load 'MM_TVDB.rb'
load 'MMCommon.rb'
load 'MM_TVDB2.rb'
load 'MM_IMDB.rb'
load 'RetrieveMeta.rb'
load 'FindDuplicates.rb'
load 'movieInfo_Specification.rb'
load 'Internals.rb'

module MediaManager
  extend MMCommon
	#scan_media scans for recognizable formats, attempts get metadata for each result, and stores the results in mediaFiles SQL Table
	#verbose speaks for itself
	#scanDirectory is an optional argument, if a directory is given that dir will be scanned instead of the directory[ies]
	#	specified in the config file.
	#scanItemLimit is the maximum number of files to scan, this number only includes files with recognized extentions.  
	#	The default of zero indicates no limit.
	#updateDuplicates? is used to specify wether you wish to update the metainfo for duplicate files, or simply ignore them.
	#	When a recognized file is found, the file is hashed and the database is searched for the hash.  If a match is found, this
	#	indicates that the file has been processed before and may be a duplicate.  If this happens, the program looks at the location
	#	the file was thought to be in previously, if it is not there for any reason the database is silently updated.  If it does exist
	#	then this option specifies what to do, update the database with the new location or use the old location.
	def self.scan_media( verbose=FALSE, scanDirectory=nil, scanItemLimit=0, updateDuplicates= :yes )
		catch :quit do
			raise "Sanity check failed!" unless sanity_check==:sane

			puts "Scanning source directories:"
			puts "This may take a moment..."
			files=[]
			files=MediaManager::FindDuplicates.scan_dirs( (scanDirectory.nil? ? nil : scanDirectory), :yes, scanItemLimit, :no) 
			
			files.each_index { |filesP|
				ignore=FALSE
				movieInfo=MediaManager::RetrieveMeta.filenameToInfo files[filesP]
				next if movieInfo==:ignore
				#pp_movieInfo movieInfo
				
				#If its a duplicate
				if movieInfo.has_key?('id')==true
					if movieInfo['Path']==files[filesP] and updateDuplicates == :yes
						puts "Silently skipping..."
						next
					end
					unless $MM_MAINT_FILE_INTEGRITY!=TRUE
						pp movieInfo['Path']
						pp files[filesP]
						s="Duplicate found and , OMG THINK OF SOME OPTIONS FOR HERE!"
						raise s
					#case MediaManager.prompt(s, :)
					#	when 
					end
				end
			
				pp_movieInfo movieInfo	
				answer= MediaManager.prompt("Is this correct?", :yes, [:edit, :skip, :drop] )
				if answer==:no||answer==:edit
					movieInfo=userCorrect movieInfo
				elsif answer==:skip||answer==:drop
					(answer==:skip) ? (puts "Skipping file...") : (puts "Dropped.  Continuing...")
					ignore=TRUE
				end

				next if ignore
				
				#Add to Mysql
				sqlAddInfo(movieInfo) unless movieInfo.include? 'id'
				sqlUpdateInfo(movieInfo) unless movieInfo.include?('id')!=TRUE

			}
			
			
		end #catch :quit
	end

	#This function is called by the user to create the Library tree of symlinks to all of the movies
	def self.createLibrary
		# categories = ['TVShows', 'Movies']
		entries=MediaManager.sqlSearch('SELECT * FROM mediaFiles')
		entries.each {|entry|
			if entry['Categorization'].empty?
				link_path="#{$MEDIA_LIBRARY_DIR}" << '/Library/Misc/' << File.basename(entry['Path'])
				File.makedirs link_path
				File.symlink( entry['Path'], link_path) unless File.exists? link_path
				next
				#raise "createLibrary():  Can't create link for file that has no category"
			end

			link_path="#{$MEDIA_LIBRARY_DIR}" << '/' << entry['Categorization'] << '/' << entry['Title'] << '/' << "Season #{entry['Season']}" << '/'
			
			File.makedirs link_path 
			#This part determins the symlink name's format
			link_path << entry['EpisodeID'].match(/\d+$/)[0] << ' - ' << entry['EpisodeName'] << entry['Path'].match(/\.[^\.]+?$/)[0]
			File.symlink(entry['Path'], link_path) unless File.exists? link_path
			
		}
		return TRUE
	end

	#This function recieves a search term from the user, a name, id number, or identifiable string
	#and if that term is ambiguous for the database, it asks the user for clarification
	# and if it is identifiable it begins playing that file to the requested host
	def play searchTerm, target=nil
		
	end

end

MediaManager.sanity_check

