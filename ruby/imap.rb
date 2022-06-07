#!/usr/bin/env ruby

require 'net/imap'
require 'getoptlong'

# defaults
auth_type = 'LOGIN'
hostname = '127.0.0.1'
username = nil
password = nil
port = 143
total_only = nil
login_only = nil

opts = GetoptLong.new(
  ['--help', GetoptLong::NO_ARGUMENT],
  ['--version', GetoptLong::NO_ARGUMENT],
  ['--hostname', '-h', GetoptLong::REQUIRED_ARGUMENT],
  ['--username', '-u', GetoptLong::REQUIRED_ARGUMENT],
  ['--password', '-p', GetoptLong::REQUIRED_ARGUMENT],
  ['--port', GetoptLong::OPTIONAL_ARGUMENT],
  ['--login', GetoptLong::NO_ARGUMENT],
  ['--plain', GetoptLong::NO_ARGUMENT],
  ['--cram-md5', GetoptLong::NO_ARGUMENT],
  ['--total-only', GetoptLong::NO_ARGUMENT],
  ['--login-only', GetoptLong::NO_ARGUMENT]
)

opts.each do |opt, arg|
  case opt
    when '--help'
      puts 'HELP'
    when '--version'
      puts 'VERSION 0.0.0'
    when '--hostname'
      hostname = arg
    when '--username'
      username = arg
    when '--password'
      password = arg
    when '--port'
      port = arg.to_i
    when '--total-only'
      total_only = true
    when '--login-only'
      login_only = true
  end
end

imap = Net::IMAP.new(hostname)
begin
  greeting = imap.authenticate(auth_type, username, password)
  puts "#{greeting.data.text}"
  return if login_only
  list = imap.list("", "*")
  lsub = imap.lsub("", "*")

  array = Array.new

  list.collect{|x| x.name}.each do |folder|
    begin
      msg = imap.status(folder, ['MESSAGES'])
      array << msg['MESSAGES']
      puts "#{folder} #{msg['MESSAGES']}" unless total_only
    rescue
      puts "#{folder} status error"
    end
  end

  puts "TOTAL: #{array.inject(:+)}"

  imap.logout
rescue => error
  puts "#{error}"
end

imap.disconnect