# -*- coding: utf-8 -*-
# Functinos for use with makeinitramfs.
# All functinos make use of @options as the
# hash of parsed commandline options.

########################################
# FileUtils inclusion

# Make the FileUtils stuff (cp, mov, etc.) available
# (verbosily if requested).
if @options[:verbose]
  include FileUtils::Verbose
else
  include FileUtils
end

########################################
# Helper functions

# Abort the program with +msg+.
def die(msg)
  abort Paint[":( #{msg}", :red, :bold]
end

# Output an informational message.
def msg(msg)
  puts Paint[":: #{msg}", :blue, :bold]
end

# Output a warning.
def warn(msg)
  puts Paint["!! Warning: #{msg}", :yellow, :bold]
end

# Output a final message and exit the program.
def finish(msg)
  puts Paint[":D #{msg}", :green, :bold]
  exit
end

# Internal method forwarding to #system; if
# @options[:verbose] is set, it will output
# the command previously.
def sh(cmd)
  puts cmd if @options[:verbose]
  system cmd
end

# Creates a temporary directory, calls the
# handed block and removes the directory after
# the block has finished. If @options[:verbose]
# is set, prints out the relevant operations.
# Yields the path to the temporary directory
# to the block (as a Pathname object).
def mktmpdir
  Dir.mktmpdir do |tmpdir|
    puts "mkdir #{tmpdir}" if @options[:verbose]
    yield(Pathname.new(tmpdir))
    puts "rm -rf #{tmpdir}" if @options[:verbose]
  end
end

# Override FileUtils' mkdir to not crash when the
# directory already exists.
alias old_mkdir mkdir
def mkdir(path, *args)
  old_mkdir(path, *args) unless File.directory?(path)
end

# Wrapper for mkfifo(1).
def mkfifo(path, opts = {})
  if opts[:mode]
    sh "mkfifo -m #{opts[:mode].to_s(8)}"
  else
    sh "mkfifo '#{path}'"
  end
end

# Wrapper for mknod(1).
def mknod(path, opts = {})
  if opts[:mode]
    sh "mknod -m #{opts[:mode].to_s(8)} '#{path}' #{opts[:type]} #{opts[:major]} #{opts[:minor]}"
  else
    sh "mknod '#{path}' #{opts[:type]} #{opts[:major]} #{opts[:minor]}"
  end
end

# Wrapper for cpio(1) or bsdcpio(1) (depending on which
# one is found). Compresses the directory +source+ into
# the file +target+ (which must not reside in +source+).
# The archive will always be created in the SVR4 format,
# i.e. with the option <tt>-H newc</tt>.
def cpio(source, target)
  # Determine the cpio command
  unless @__cpio
    if system("cpio --help > /dev/null")
      @__cpio = "cpio"
    elsif system("bsdcpio --help > /dev/null")
      @__cpio = "bsdcpio"
    else
      die("Neither cpio nor bsdcpio found.")
    end
  end

  # Switch into the source directory, so the recursive
  # directory listing will find the files relative to
  # the source directory (which is how we need them)
  target = Pathname.new(target).expand_path
  cd(source) do
    sh "find . | #@__cpio -H newc -o > '#{target}'"
  end
end

# Wrapper for lzop(1).
def lzop(path, level = 7)
  sh "lzop -#{level.to_i} '#{path}'"
end

########################################
# Main functions for handling lines
# in the device table file

# Creates/modifies a single device/file. Takes the path (name) of
# the device/file, the type as denoted in the device table file,
# and any options (i.e. :mode, :major, and :minor; the last two
# can be ommitted for non-device files).
def apply_device(name, type, opts)
  case type
  when "f" then chmod opts[:mode], name
  when "d" then mkdir name,  opts
  when "c" then mknod name,  opts.merge({:type => "c"})
  when "b" then mknod name,  opts.merge({:type => "b"})
  when "p" then mkfifo name, opts
  else
    warn "Unknown type #{type}, ignoring."
  end
end

# Handles a single +line+ of a device table file,
# creates the necessary device(s) under the
# +target+ directory, and sets the appropriate
# permissions according to the line.
def handle_device_line(line, target)
  # Ignore empty lines and comments
  return if line.strip.empty? or line =~ /^\s*#/

  # Split the line up into its components.
  ary                             = line.split
  path, type                      = ary[0..1]
  mode                            = ary[2].to_i(8)
  uid, gid                        = ary[3,4].map(&:to_i)
  major, minor, start, inc, count = ary[5..-1].map{|i| i == "-" ? nil : i.to_i}

  # Set up the options hash
  hsh = {:mode => mode} # mode is required anyway
  hsh[:major] = major if major
  hsh[:minor] = minor if minor

  # Apply the current line
  if start && inc && count && !count.zero? # Automatic numbering requested
    num = start
    start.upto(count - 1) do
      # Name of the target device
      name         = "#{target}/#{path}#{num}"

      # Create/modify device
      apply_device(name, type, hsh)
      chown(uid, gid, name)

      # Prepare for next iteration
      num         += inc
      hsh[:minor] += 1
    end
  else # Just a single device
    name        = "#{target}/#{path}"

    apply_device(name, type, hsh)
    chown uid, gid, name
  end
end
