require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/file_system'

describe Puppet::FileSystem::PathPattern do
  include PuppetSpec::Files
  InvalidPattern = Puppet::FileSystem::PathPattern::InvalidPattern

  describe 'relative' do
    it "can not be created with a traversal up the directory tree" do
      expect do
        Puppet::FileSystem::PathPattern.relative("my/../other")
      end.to raise_error(InvalidPattern, "PathPatterns cannot be created with directory traversals.")
    end

    it "can be created with a '..' prefixing a filename" do
      Puppet::FileSystem::PathPattern.relative("my/..other").to_s.should eq("my/..other")
    end

    it "can be created with a '..' suffixing a filename" do
      Puppet::FileSystem::PathPattern.relative("my/other..").to_s.should eq("my/other..")
    end

    it "can be created with a '..' embedded in a filename" do
      Puppet::FileSystem::PathPattern.relative("my/ot..her").to_s.should eq("my/ot..her")
    end

    it "can not be created with a \\0 byte embedded" do
      expect do
        Puppet::FileSystem::PathPattern.relative("my/\0/other")
      end.to raise_error(InvalidPattern, /PathPatterns cannot be created with a zero byte./)
    end

    it "can not be created with a windows drive" do
      expect do
        Puppet::FileSystem::PathPattern.relative("c:\\relative\\path")
      end.to raise_error(InvalidPattern, "A relative PathPattern cannot be prefixed with a drive.")
    end

    it "can not be created with a windows drive (with space)" do
      expect do
        Puppet::FileSystem::PathPattern.relative(" c:\\relative\\path")
      end.to raise_error(InvalidPattern, "A relative PathPattern cannot be prefixed with a drive.")
    end

    it "can not create an absolute relative path" do
      expect do
        Puppet::FileSystem::PathPattern.relative("/no/absolutes")
      end.to raise_error(InvalidPattern, "A relative PathPattern cannot be an absolute path.")
    end

    it "can not create an absolute relative path (with space)" do
      expect do
        Puppet::FileSystem::PathPattern.relative("\t/no/absolutes")
      end.to raise_error(InvalidPattern, "A relative PathPattern cannot be an absolute path.")
    end

    it "can not create a relative path that is a windows path relative to the current drive" do
      expect do
        Puppet::FileSystem::PathPattern.relative("\\no\relatives")
      end.to raise_error(InvalidPattern, "A PathPattern cannot be a Windows current drive relative path.")
    end

    it "creates a relative PathPattern from a valid relative path" do
      Puppet::FileSystem::PathPattern.relative("a/relative/path").to_s.should eq("a/relative/path")
    end

    it "is not absolute" do
      Puppet::FileSystem::PathPattern.relative("a/relative/path").should_not be_absolute
    end
  end

  describe 'absolute' do
    it "can not create a relative absolute path" do
      expect do
        Puppet::FileSystem::PathPattern.absolute("no/relatives")
      end.to raise_error(InvalidPattern, "An absolute PathPattern cannot be a relative path.")
    end

    it "can not create an absolute path that is a windows path relative to the current drive" do
      expect do
        Puppet::FileSystem::PathPattern.absolute("\\no\\relatives")
      end.to raise_error(InvalidPattern, "A PathPattern cannot be a Windows current drive relative path.")
    end

    it "creates an absolute PathPattern from a valid absolute path" do
      Puppet::FileSystem::PathPattern.absolute("/an/absolute/path").to_s.should eq("/an/absolute/path")
    end

    it "creates an absolute PathPattern from a valid Windows absolute path" do
      Puppet::FileSystem::PathPattern.absolute("c:/absolute/windows/path").to_s.should eq("c:/absolute/windows/path")
    end

    it "is absolute" do
      Puppet::FileSystem::PathPattern.absolute("c:/absolute/windows/path").should be_absolute
    end

    it "can be created with a '..' embedded in a filename on windows", :if => Puppet.features.microsoft_windows? do
      Puppet::FileSystem::PathPattern.absolute(%q{c:\..my\ot..her\one..}).to_s.should eq(%q{c:\..my\ot..her\one..})
    end
  end

  it "prefixes the relative path pattern with another path" do
    pattern = Puppet::FileSystem::PathPattern.relative("docs/*_thoughts.txt")
    prefix = Puppet::FileSystem::PathPattern.absolute("/prefix")

    absolute_pattern = pattern.prefix_with(prefix)

    absolute_pattern.should be_absolute
    absolute_pattern.to_s.should eq(File.join("/prefix", "docs/*_thoughts.txt"))
  end

  it "refuses to prefix with a relative pattern" do
    pattern = Puppet::FileSystem::PathPattern.relative("docs/*_thoughts.txt")
    prefix = Puppet::FileSystem::PathPattern.relative("prefix")

    expect do
      pattern.prefix_with(prefix)
    end.to raise_error(InvalidPattern, "An absolute PathPattern cannot be a relative path.")
  end

  it "applies the pattern to the filesystem as a glob" do
    dir = tmpdir('globtest')
    create_file_in(dir, "found_one")
    create_file_in(dir, "found_two")
    create_file_in(dir, "third_not_found")

    pattern = Puppet::FileSystem::PathPattern.relative("found_*").prefix_with(
      Puppet::FileSystem::PathPattern.absolute(dir))

    pattern.glob.should include(File.join(dir, "found_one"))
    pattern.glob.should include(File.join(dir, "found_two"))
    pattern.glob.should_not include(File.join(dir, "third_not_found"))
  end

  def create_file_in(dir, name)
    File.open(File.join(dir, name), "w") { |f| f.puts "data" }
  end
end
