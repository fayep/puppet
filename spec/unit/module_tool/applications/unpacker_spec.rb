require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'

describe Puppet::ModuleTool::Applications::Unpacker, :fails_on_windows => true do
  include PuppetSpec::Files

  let(:target) { tmpdir("unpacker") }

  context "initialization" do
    it "should support filename and basic options" do
      Puppet::ModuleTool::Applications::Unpacker.new("myusername-mytarball-1.0.0.tar.gz", :target_dir => target)
    end

    it "should raise ArgumentError when filename is invalid" do
      expect { Puppet::ModuleTool::Applications::Unpacker.new("invalid.tar.gz", :target_dir => target) }.to raise_error(ArgumentError)
    end
  end

  context "#run" do
    let(:cache_base_path) { Pathname.new(tmpdir("unpacker")) }
    let(:filename) { tmpdir("module") + "/myusername-mytarball-1.0.0.tar.gz" }
    let(:build_dir) { Pathname.new(tmpdir("build_dir")) }
    let(:unpacker) do
      Puppet::ModuleTool::Applications::Unpacker.new(filename, :target_dir => target)
    end

    before :each do
      # Mock redhat for most test cases
      Facter.stubs(:value).with("operatingsystem").returns("Redhat")
      build_dir.stubs(:mkpath => nil, :rmtree => nil, :children => [])
      unpacker.stubs(:build_dir).at_least_once.returns(build_dir)
      FileUtils.stubs(:mv)
    end

    context "on linux" do
      it "should attempt to untar file to temporary location using system tar" do
        Puppet::Util.expects(:execute).with("tar xzf #{filename} -C #{build_dir}").returns(true)
        Puppet::Util.expects(:execute).with("find #{build_dir} -type d -exec chmod 755 {} +").returns(true)
        Puppet::Util.expects(:execute).with("find #{build_dir} -type f -exec chmod 644 {} +").returns(true)
        Puppet::Util.expects(:execute).with("chown -R #{build_dir.stat.uid}:#{build_dir.stat.gid} #{build_dir}").returns(true)
        unpacker.run
      end
    end

    context "on solaris" do
      before :each do
        Facter.expects(:value).with("operatingsystem").returns("Solaris")
      end

      it "should attempt to untar file to temporary location using gnu tar" do
        Puppet::Util.stubs(:which).with('gtar').returns('/usr/sfw/bin/gtar')
        Puppet::Util.expects(:execute).with("gtar xzf #{filename} -C #{build_dir}").returns(true)
        Puppet::Util.expects(:execute).with("find #{build_dir} -type d -exec chmod 755 {} +").returns(true)
        Puppet::Util.expects(:execute).with("find #{build_dir} -type f -exec chmod 644 {} +").returns(true)
        Puppet::Util.expects(:execute).with("chown -R #{build_dir.stat.uid}:#{build_dir.stat.gid} #{build_dir}").returns(true)
        unpacker.run
      end

      it "should throw exception if gtar is not in the path exists" do
        Puppet::Util.stubs(:which).with('gtar').returns(nil)
        expect { unpacker.run }.to raise_error RuntimeError, "Cannot find the command 'gtar'. Make sure GNU tar is installed, and is in your PATH."
      end
    end
  end

end
