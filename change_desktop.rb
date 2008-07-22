#!/usr/bin/env ruby

require 'rmagick'
require 'rubygems'
require 'plist'
require 'rbosa'
require 'yaml'
require 'fileutils'

def to_plist( fpath, cts = nil )
  if cts
    File.open( fpath + ".tmp", 'w') do |out|
      out << cts
    end
    FileUtils.mv( fpath + ".tmp", fpath )
  end
  
  `plutil -convert binary1 #{fpath}`
end

def to_xml( fpath )
  `plutil -convert xml1 #{fpath}`
  File.read( fpath )
end

def generate_mirrored( img )
  baseout = File.join( File.dirname(img), '.mirror')
  out = File.join( baseout, File.basename(img) )
  unless File.exists?(baseout)
    FileUtils.mkdir( baseout )
  end
  
  image = Magick::Image.read( img ).first
  image.flop!
  image.write( out )
  out
end

if( ARGV.include?("--gui") )

  exit 0
end

logfile = File.join( File.dirname(__FILE__), '.change_desktop.log')
log = []
if File.exists?( logfile )
  log = YAML.load( File.read(logfile) )
end

base_bgs = "/Users/jmoses/Pictures/Desktop Backgrounds/interfacelift/"

new_path = ""
pictures = []
Dir["#{base_bgs}/*"].each do |pic|
  next if File.directory?(pic)
  pictures << pic
end

if pictures.all? {|pic| log.include?(pic) }
  log = []
else
  pictures = pictures.reject {|pic| log.include?(pic) }
end
puts "Picking 1 background out of #{pictures.size}"
new_path = pictures[ rand(pictures.size) ]
fname = "/Users/jmoses/Library/Preferences/com.apple.desktop.plist"
# new_path = "/Users/jmoses/Pictures/Desktop Backgrounds/interfacelift/01540_driftwood_1440x900.jpg"

data = Plist::parse_xml( to_xml( fname ) )

mirror = generate_mirrored(new_path)

data["Background"].each_pair do |key,val|
  if key != '69671424'
    path = mirror
  else
    path = new_path
  end
  
  puts "Using #{path} for #{key}"
  
  # puts "Current paths for #{key}"
  # puts val["ImageFilePath"]
  val["ImageFilePath"] = path
  # puts val["NewImageFilePath"]
  val["NewImageFilePath"] = path
end

to_plist(fname, data.to_plist)

## Force reload of desktop backgrounds.  Yeah!
finder = OSA.app("Finder")
finder.desktop_picture = finder.desktop_picture

log << new_path
File.open(logfile, 'w') {|out| out << log.to_yaml }
