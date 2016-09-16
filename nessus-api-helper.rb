#!/usr/bin/env ruby
# coding: utf-8
require 'optparse'
require 'json'
require 'csv'
require 'set'
require 'nokogiri'
require 'net/https'
require 'erb'

require 'pry'

class NessusAPIHelper

  def initialize()
    @use_ssl = true
  end

  def run_from_options(argv)
    parse_options(argv)

    get_scan_files(@options)
    
#    if @options[:type]

#    elsif@options[:jira_search]
#      get_findings(@options)
#    else
      # do nothing
#    end
  end

  def parse_options(argv)
    argv[0] = '--help' unless argv[0]
    @options = {}
    OptionParser.new do |opts|
      opts.banner = <<-USAGE
Usage:
  #{__FILE__} [options]

Examples:

  Find JIRA issue by key and display
    #{__FILE__} -p 8834 -f 3

Options:
      USAGE
      opts.on('-d', '--directory DIR', 'Where to put the downloaded files') do |p|
        @options[:directory] = p
      end
      opts.on('-p', '--port PORT', 'Port the Nessus server is running on') do |p|
        @options[:port] = p
      end
      opts.on('-f', '--folder ID', 'Folder id (integer) to search for scans') do |p|
        @options[:folder_id] = p
      end
      opts.on('-l', '--last_modified HH:MM', 'Time since a scan was last modified, can be any string that DateTime.parse will accept') do |p|
        @options[:last_modified] = p
      end
      opts.on('-v', '--verbose', 'Show things like risk level in the output') do |p|
        @options[:verbose] = p
      end
    end.parse!(argv)
  end

  # look for the list of scans
  # curl -s -k -H "X-ApiKeys: accessKey=foo; secretKey=bar" https://localhost:8834/scans
  def get_request(options, path)

    result = {}

    http = Net::HTTP.new(ENV['NESSUS_HOST'], options[:port])
    http.use_ssl = @use_ssl
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    http.start do |http|
      req = Net::HTTP::Get.new(path)

      # we make an HTTP basic auth by passing the
      # username and password
      req['X-ApiKeys'] = "accessKey=#{ENV['NESSUS_ACCESS_KEY']}; secretKey=#{ENV['NESSUS_SECRET_KEY']}"
      
      resp, data = http.request(req)
      
      if resp.code.eql? '200'
        #print "Data: " +  JSON.pretty_generate(JSON.parse(resp.body.to_s))
        result = JSON.parse(resp.body.to_s)
      else
        puts "Error: " + resp.code.to_s + "\n" + resp.body
      end
    end

    return result
  end

  # post something to the API
  def post_request(options, path, post_data)

    result = {}

    http = Net::HTTP.new(ENV['NESSUS_HOST'], options[:port])
    http.use_ssl = @use_ssl
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    http.start do |http|
      req = Net::HTTP::Post.new(path)

      req['X-ApiKeys'] = "accessKey=#{ENV['NESSUS_ACCESS_KEY']}; secretKey=#{ENV['NESSUS_SECRET_KEY']}"
      req.body = post_data
      
      resp, data = http.request(req)
      
      if resp.code.eql? '200'
        #print "Data: " +  JSON.pretty_generate(JSON.parse(resp.body.to_s))
        result = JSON.parse(resp.body.to_s)
      else
        puts "Error: " + resp.code.to_s + "\n" + resp.body
      end
    end

    return result
  end

  # download a file from the API
  def get_file(options, path, filename)

    result = {}

    http = Net::HTTP.new(ENV['NESSUS_HOST'], options[:port])
    http.use_ssl = @use_ssl
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    http.start do |http|
      req = Net::HTTP::Get.new(path)

      req['X-ApiKeys'] = "accessKey=#{ENV['NESSUS_ACCESS_KEY']}; secretKey=#{ENV['NESSUS_SECRET_KEY']}"
      
      resp, data = http.request(req)
      
      open("#{options[:directory]}/#{filename}", "wb") do |file|
        file.write(resp.body)
      end
      
      if resp.code.eql? '200'
        puts " downloaded #{filename} to #{options[:directory]}"
      elsif resp.code.eql? '409'
        # the server isn't ready yet, it is
        # still exporting the file
        sleep(1)
        print '.'
        get_file(options, path, filename)
      else
        puts "Error: " + resp.code.to_s + ": " + resp.body
      end
    end

    return result
  end

  
  # download the files from the scans
  def get_scan_files(options)

    last_modified = DateTime.parse(options[:last_modified]).to_time.to_i

    query_params = URI.encode_www_form({:folder_id => options[:folder_id], :last_modification_date => last_modified}) if options[:folder_id]
    path = ['/scans', query_params].join("?")
    
    scans = get_request(options, path)

    # loop through the scans and ask nessus to export the last scan result
    # it will return a file id that we can issue a GET on
    scans['scans'].each do | scan |

      #puts "Name: #{scan['name']}"
      #puts "Last mod date: #{Time.at(scan['last_modification_date'])}"
      
      path = "/scans/#{scan['id']}/export"
      file = post_request(options, path, "format=csv")

      # now grab the file and save it
      path = "/scans/#{scan['id']}/export/#{file['file']}/download"
      filename = "#{scan['name'].gsub(/\s/, '_')}_#{scan['last_modification_date']}.csv"
      get_file(options, path, filename)
      
    end
  end
end

NessusAPIHelper.new.run_from_options(ARGV) if __FILE__ == $PROGRAM_NAME
