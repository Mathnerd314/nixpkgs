# Usage:
# rsync --no-h --no-motd --list-only -r --exclude-from=rsync-excludes-gnu rsync://ftp.gnu.org/gnu/ | ruby parse_listing.rb > gnu.json
# rsync --no-h --no-motd --list-only -r --exclude-from=rsync-excludes-gnome rsync://mirror.umd.edu/gnome/ | ruby parse_listing.rb > gnome.json
# rsync --no-h --no-motd --list-only --filter ". rsync-filter-linux" -r rsync://rsync.kernel.org/pub | ruby parse_listing.rb > kernel.json

require 'logger'
require 'date'
require 'optparse'
require 'optparse/date'
require 'json'

$log = Logger.new(STDERR)
$log.level = Logger::INFO


## from https://github.com/puppetlabs/puppet/blob/master/lib/puppet/provider/package/rpm.rb (Apache 2)

# This is an attempt at implementing RPM's
# lib/rpmvercmp.c rpmvercmp(a, b) in Ruby.
#
# Some of the things in here look REALLY
# UGLY and/or arbitrary. Our goal is to
# match how RPM compares versions, quirks
# and all.
#
# I've kept a lot of C-like string processing
# in an effort to keep this as identical to RPM
# as possible.
#
# returns 1 if str1 is newer than str2,
#         0 if they are identical
#        -1 if str1 is older than str2
def rpmvercmp(str1, str2)
  return 0 if str1 == str2

  front_strip_re = /^[^A-Za-z0-9~]+/
  segment_re = /^[A-Za-z0-9]/
  # these represent RPM rpmio/rpmstring.c functions
  risalnum = /[A-Za-z0-9]/
  risdigit = /^[0-9]+/
  risalpha = /[A-Za-z]/

  while str1.length > 0 or str2.length > 0
    # trim anything that's !risalnum() and != '~' off the beginning of each string
    str1 = str1.gsub(front_strip_re, '')
    str2 = str2.gsub(front_strip_re, '')

    # "handle the tilde separator, it sorts before everything else"
    if /^~/.match(str1) && /^~/.match(str2)
      # if they both have ~, strip it
      str1 = str1[1..-1]
      str2 = str2[1..-1]
    elsif /^~/.match(str1)
      return -1
    elsif /^~/.match(str2)
      return 1
    end

    break if str1.length == 0 or str2.length == 0

    # "grab first completely alpha or completely numeric segment"
    isnum = false
    # if the first char of str1 is a digit, grab the chunk of continuous digits from each string
    if risdigit.match(str1)
      if str1 =~ /^[0-9]+/
        segment1 = $~.to_s
        str1 = $~.post_match
      else
        segment1 = ''
      end
      if str2 =~ /^[0-9]+/
        segment2 = $~.to_s
        str2 = $~.post_match
      else
        segment2 = ''
      end
      isnum = true
    # else grab the chunk of continuous alphas from each string (which may be '')
    else
      if str1 =~ /^[A-Za-z]+/
        segment1 = $~.to_s
        str1 = $~.post_match
      else
        segment1 = ''
      end
      if str2 =~ /^[A-Za-z]+/
        segment2 = $~.to_s
        str2 = $~.post_match
      else
        segment2 = ''
      end
    end

    # if the segments we just grabbed from the strings are different types (i.e. one numeric one alpha),
    # where alpha also includes ''; "numeric segments are always newer than alpha segments"
    if segment2.length == 0
      return 1 if isnum
      return -1
    end

    if isnum
      # "throw away any leading zeros - it's a number, right?"
      segment1 = segment1.gsub(/^0+/, '')
      segment2 = segment2.gsub(/^0+/, '')
      # "whichever number has more digits wins"
      return 1 if segment1.length > segment2.length
      return -1 if segment1.length < segment2.length
    end

    # "strcmp will return which one is greater - even if the two segments are alpha
    # or if they are numeric. don't return if they are equal because there might
    # be more segments to compare"
    rc = segment1 <=> segment2
    return rc if rc != 0
  end #end while loop

  # if we haven't returned anything yet, "whichever version still has characters left over wins"
  if str1.length > str2.length
    return 1
  elsif str1.length < str2.length
    return -1
  else
    return 0
  end
end

# this method is a native implementation of the
# compare_values function in rpm's python bindings,
# found in python/header-py.c, as used by yum.
def compare_values(s1, s2)
  if s1.nil? && s2.nil?
    return 0
  elsif ( not s1.nil? ) && s2.nil?
    return 1
  elsif s1.nil? && (not s2.nil?)
    return -1
  end
  return rpmvercmp(s1, s2)
end


## from https://github.com/fedora-infra/anitya/blob/master/anitya/lib/backends/__init__.py (GPLv2+), slightly modified

# Split (upstream) version into version and release candidate string +
# release candidate number if possible
# 
# Code from Till Maas as part of
# `cnucnu <https://fedorapeople.org/cgit/till/public_git/cnucnu.git/>`_
def split_rc(version)
    rc_upstream_regex = /^(.*?)\.?(-?(rc|pre|beta|alpha|dev|a|b)([0-9]*))(.*?)$/i
    match = rc_upstream_regex.match(version)
    return [version, nil, nil, nil] if not match
        
    rc_str = match[2]
    return [match[1], match[3], match[4], match[5]] if not rc_str.empty?
    
    # if version contains a dash, but no release candidate string is found,
    # v != version, therefore use version here
    # Example version: 1.8.23-20100128-r1100
    # Then: v=1.8.23, but rc_str=""
    return [version, nil, nil, nil]
end

# Compare two upstream versions
# 
# Code from Till Maas as part of
# `cnucnu <https://fedorapeople.org/cgit/till/public_git/cnucnu.git/>`_
# 
# :Parameters:
#     v1 : str
#         Upstream version string 1
#     v2 : str
#         Upstream version string 2
# 
# :return:
#     - -1 - second version newer
#     - 0  - both are the same
#     - 1  - first version newer
# 
# :rtype: int
def upstream_cmp(v1, v2)

    v1, rc1, rcn1, rest1 = split_rc(v1)
    v2, rc2, rcn2, rest2 = split_rc(v2)

    diff = compare_values(v1, v2)
    return diff if diff != 0

    if rc1 and rc2
        # both are rc, higher rc is newer
        # rc > pre > beta > alpha
        diff = compare_values(rc1.downcase, rc2.downcase)
        return diff if diff != 0
        # both have rc number
        diff = compare_values(rcn1, rcn2)
        return diff if diff != 0
    else
        # only first is rc, then second is newer
        return -1 if rc1
        # only second is rc, then first is newer
        return 1 if rc2
    end
    # same rc, compare rest
    return compare_values(rest1, rest2)
end

## from https://github.com/Phreedom/nixpkgs-monitor/blob/master/package-updater.rb, license unknown

def extension_cleanup!(tarball)
  10.times do
    # Remove all compression extensions, as we consider them to be the same
    tarball.gsub!(/(?:\.gz|\.Z|\.bz2?|\.tbz|\.tbz2|\.lzma|\.lz|\.zip|\.xz|[-\.]tar|\.tgz|\.7z|\.shar|\.cpio)$/, "")
  end
  return tarball
end

def parse_tarball_from_url(url)
  url_clean = extension_cleanup!(""+url)
  package_name = file_version = nil
  if url_clean =~ %r{/([^/]*)$}
      tarball = $1
      if tarball =~ /^(.+?)[._-][vV]?([^A-Za-z].*)$/
        package_name = $1
        file_version = $2
      elsif tarball =~ /^([a-zA-Z]+?)[._-]?(\d[^A-Za-z].*)$/
        package_name = $1
        file_version = $2
      elsif tarball =~ /^([a-zA-Z._-]+?)[._-]?([a-zA-Z]+\d[^A-Za-z].*)$/
        package_name = $1
        file_version = $2
      end

      if file_version
        # catch trailing junk like -doc and -examples
        if file_version =~ /^(.+?)((?:[._-](?:[a-zA-Z+]+|win32|win64|i?[345]86|x86|x64\|hpux10|x86_64|woe32))+)$/
          package_name += $2
          file_version = $1
        end
      else
        $log.info "falling back to full url for #{url}"
        package_name = tarball
        file_version = url_clean
      end
      
      return [ package_name, file_version ]
  end

  $log.info "Failed to parse url #{url}"
  return [nil, nil]
end

since = DateTime.new
prefix = ""

OptionParser.new do |o|
  o.on("-v", "Verbose output. Can be specified multiple times") do
    log.level -= 1
  end

  o.on("--since D", DateTime, "Filter to files since DATE") do |d|
    since = d
  end

  o.on("--prefix S", String, "Url prefix") do |p|
    prefix = p
  end

  o.on("-h", "--help", "Show this message") do
    puts o
    exit
  end

  begin
    o.parse!(ARGV)
  rescue
    abort "Wrong parameters: #{$!}. See --help for more information."
  end
end

pkgs = {}

ARGF.each_line do |line|
  line.strip!
  next if not /^-[r-][w-][x-][r-][w-][x-][r-][w-][x-] /.match(line) # skip MOTD etc.
  perms, size, date, time, pkg = line.split(" ")
  if not pkg
    $log.info "Failed to parse line: #{line}" 
    next
  end
  date = DateTime.parse("#{date} #{time}")
  next if date < since
  size = Integer(size)
  next if size <= 0
  name, version = parse_tarball_from_url(pkg)
  next if not name
  hash = { :name => name, :version => version, :size => size, :url => prefix + pkg, :date => date }
  # $log.debug "#{hash}"
  if pkgs[name]
    diff = upstream_cmp(pkgs[name][:version], hash[:version])
    if diff < 0
      # newer version
      pkgs[name] = hash
    elsif diff == 0
      # same version - use smallest file
      if pkgs[name][:size] > hash[:size]
        pkgs[name] = hash
      end
    end
    # old version, ignore
  else
    # new package
    pkgs[name] = hash
  end
end

puts "#{JSON.pretty_generate(pkgs.values.sort_by { |v| v[:date] })}"
