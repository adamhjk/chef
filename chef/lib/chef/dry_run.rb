#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2011 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'flexmock'
require 'chef/log'

class Chef
  class DryRun
    class << self
      include FlexMock::MockContainer

      def disable(resource, action, &block)
        if Chef::Config[:dry_run]
          Chef::Log.debug("#{resource} disabling dry run mocks")
          flexmock_close
          begin
            r = block.call
          ensure
            start(resource, action)
          end
          r
        else
          block.call
        end
      end

      def start(resource, action)
        Chef::Log.debug("#{resource} initializing dry run mocks")
        file_mocks(resource, action)
        fileutils_mocks(resource, action)
        tempfile_mocks(resource, action)
        shellout_mocks(resource, action)
        command_mocks(resource, action)
      end

      def command_mocks(resource, action)
        # This is going to be really gross, but since Chef::Mixin::Command is a legit mixin, we need to mock
        # every instance of it, on every class.
        ObjectSpace.each_object(Chef::Mixin::Command) do |obj|
          if obj.respond_to?(:run_command)
            flexmock(obj, "Chef::Mixin::Command Mock for run_command #{obj.class.to_s}").should_receive(:run_command).and_return do |*args|
              Chef::Log.warn("#{resource} would have run #{args.inspect}")
              0
            end
          end
          if obj.respond_to?(:popen4)
            flexmock(obj, "Chef::Mixin::Command Mock for popen4 #{obj.class.to_s}").should_receive(:popen4).and_return do |*args|
              Chef::Log.warn("#{resource} would have run #{args.inspect}")
              flexmock("popen4 exitstatus response for #{args.inspect}", :exitstatus => 0)
            end
          end
        end
      end

      def shellout_mocks(resource, action)
        flexmock(Chef::ShellOut, "Chef::ShellOut Class Mock").should_receive(:new).and_return do |*args|
          Chef::Log.warn("#{resource} would have run #{args.inspect}")
          shellout_mock = flexmock("Chef::ShellOut Mock for #{args[0]}")
          shellout_mock.should_receive(:run_command).and_return(shellout_mock)
          shellout_mock.should_receive(:error!).and_return(nil)
          shellout_mock.should_receive(:invalid!).and_return(nil)
          shellout_mock.should_receive(:live_stream=).and_return(nil)
          shellout_mock
        end
      end

      def tempfile_mocks(resource, action)
        flexmock(Tempfile, "Tempfile Class") do |tempfile_mock|
          tempfile_mock.should_receive(:open).with(String).and_return do |arg|
            Chef::Log.debug("#{resource} opened a tempfile")
            disable(resource, action) { Tempfile.open(arg) }
          end
          tempfile_mock.should_receive(:open).with(String, Proc).and_return do |arg, block|
            Chef::Log.debug("#{resource} opened a tempfile")
            disable(resource, action) { Tempfile.open(arg, &block) }
          end
        end
      end

      # Mock the Read and Write methods of the File class
      def file_mocks(resource, action)
        # File reading is safe, but goes through open - so we need to pass through in dry dun
        flexmock(File, "File Class") do |file_mock|
          # File reading
          file_mock.should_receive(:open).with(String, "r").and_return do |filename, mode|
            Chef::Log.debug("#{resource} opened file #{filename} with mode #{mode}")
            disable(resource, action) { File.open(filename, mode) }
          end
          file_mock.should_receive(:open).with(String, "rb").and_return do |filename, mode|
            Chef::Log.debug("#{resource} opened file #{filename} with mode #{mode}")
            disable(resource, action) { File.open(filename, mode) }
          end
          file_mock.should_receive(:open).with(String, "r", Proc).and_return do |filename, mode, block|
            Chef::Log.debug("#{resource} opened file #{filename} with mode #{mode}")
            disable(resource, action) { block.call(File.open(filename, mode)) }
          end
          file_mock.should_receive(:open).with(String, "rb", Proc).and_return do |filename, mode, block|
            Chef::Log.debug("#{resource} opened file #{filename} with mode #{mode}")
            disable(resource, action) { block.call(File.open(filename, mode)) }
          end

          # File writing
          file_mock.should_receive(:open).with(String, /w(\+*)/, Proc).and_return do |filename, mode, filehandle_block|
            write_file_mock = flexmock("Fake #{filename}")
            write_file_mock.should_receive(:write).with(String).and_return do |string|
              Chef::Log.warn("#{resource} would set the contents of #{filename} to:") 
              Chef::Log << "#{string}\n"
              true
            end
            write_file_mock.should_receive(:print).with(String).and_return do |string|
              Chef::Log.warn("#{resource} would set the contents of #{filename} to:") 
              Chef::Log << "#{string}\n"
              true
            end
            write_file_mock.should_receive(:puts).with(String).and_return do |string|
              Chef::Log.warn("#{resource} would set the contents of #{filename} to:") 
              Chef::Log << "#{string}\n"
              true
            end
            Chef::Log.warn("#{resource} would overwrite file at #{filename}")
            filehandle_block.call(write_file_mock)
          end

          file_mock.should_receive(:open).with(String, /w(\+*)/, Proc).and_return do |filename, mode|
            write_file_mock = flexmock("Fake #{filename}")
            write_file_mock.should_receive(:write).with(String).and_return do |string|
              Chef::Log.warn("#{resource} would set the contents of #{filename} to:") 
              Chef::Log << "#{string}\n"
              true
            end
            write_file_mock.should_receive(:print).with(String).and_return do |string|
              Chef::Log.warn("#{resource} would set the contents of #{filename} to:") 
              Chef::Log << "#{string}\n"
              true
            end
            write_file_mock.should_receive(:puts).with(String).and_return do |string|
              Chef::Log.warn("#{resource} would set the contents of #{filename} to:") 
              Chef::Log << "#{string}\n"
              true
            end
            write_file_mock.should_receive(:close).and_return(true)

            Chef::Log.warn("#{resource} would overwrite file at #{filename}")
            write_file_mock
          end

          # File appending
          file_mock.should_receive(:open).with(String, "a", Proc).and_return do |filename, mode, filehandle_block|
            write_file_mock = flexmock("Fake #{filename}")
            write_file_mock.should_receive(:write).with(String).and_return do |string|
              Chef::Log.warn("#{resource} would append to the contents of #{filename}:") 
              Chef::Log << "#{string}\n"
              true
            end
            write_file_mock.should_receive(:print).with(String).and_return do |string|
              Chef::Log.warn("#{resource} would append to the contents of #{filename}:") 
              Chef::Log << "#{string}\n"
              true
            end
            write_file_mock.should_receive(:puts).with(String).and_return do |string|
              Chef::Log.warn("#{resource} would append the contents of #{filename}:") 
              Chef::Log << "#{string}\n"
              true
            end
            filehandle_block.call(write_file_mock)
          end

          # File deletion
          file_mock.should_receive(:delete).with(FlexMock.any).and_return do |file|
            Chef::Log.warn("#{resource} would delete #{file}")
            true
          end

          # File ownership
          file_mock.should_receive(:chown).with(FlexMock.any, FlexMock.any, FlexMock.any).and_return do |owner, group, file|
            Chef::Log.warn("#{resource} would chown #{file} owner to #{owner ? owner : 'nil'}, and group to #{group ? group : 'nil'}")
            true
          end

          # File modes
          file_mock.should_receive(:chmod).and_return do |mode, file|
            Chef::Log.warn("#{resource} would chmod #{file} to #{sprintf("%o" % octal_mode(mode))}")
            true
          end

          # File utime
          file_mock.should_receive(:utime).with(Time, Time, String).and_return do |atime, mtime, path|
            Chef::Log.warn("#{resource} would set atime to #{atime} and mtime to #{mtime} on #{path}")
            true
          end

          # File rename
          file_mock.should_receive(:rename).with(String, String).and_return do |from, to|
            Chef::Log.warn("#{resource} would rename #{from} to #{to}")
            true
          end

          # File unlink
          file_mock.should_receive(:unlink).with(String).and_return do |file|
            Chef::Log.warn("#{resource} would unlink #{file}")
            true
          end

          # File lchown
          file_mock.should_receive(:lchown).with(FlexMock.any, FlexMock.any, String) do |owner, group, link|
            Chef::Log.warn("#{resource} would chown #{link} owner to #{owner ? owner : 'nil'}, and group to #{group ? group : 'nil'}")
            true
          end

          # File symlink
          file_mock.should_receive(:symlink).with(String, String) do |from, to|
            Chef::Log.warn("#{resource} would symlink #{from} to #{to}")
            true
          end

          # File link
          file_mock.should_receive(:link).with(String, String) do |from, to|
            Chef::Log.warn("#{resource} would link #{from} to #{to}")
            true
          end

        end
      end

      def fileutils_mocks(resource, action)
        flexmock(FileUtils, "FileUtils Class") do |fileutils_mock|
          # chown_R
          fileutils_mock.should_receive(:chown_R).with(FlexMock.any, FlexMock.any, String).and_return do |owner, group, path|
            Chef::Log.warn("#{resource} would recursively chown #{path} with owner #{owner} and group #{group}")
            true
          end

          # rm_f
          fileutils_mock.should_receive(:rm_f).with(String).and_return do |path|
            Chef::Log.warn("#{resource} would recursively delete #{path}")
            true
          end

          # ln_sf
          fileutils_mock.should_receive(:ln_sf).with(String, String).and_return do |from, to|
            Chef::Log.warn("#{resource} would symlink #{from} to #{to}")
          end

          # mkdir_p 
          fileutils_mock.should_receive(:mkdir_p).with(String).and_return do |dir|
            Chef::Log.warn("#{resource} would create directory #{dir}")
            true
          end

          # cp
          fileutils_mock.should_receive(:cp).with(String, String, Hash).and_return do |from, to, options|
            Chef::Log.warn("#{resource} would copy #{from} to #{to}")
            true
          end
          fileutils_mock.should_receive(:cp).with(String, String).and_return do |from, to|
            Chef::Log.warn("#{resource} would copy #{from} to #{to}")
            true
          end

          # rm
          fileutils_mock.should_receive(:rm).with(String).and_return do |file|
            Chef::Log.warn("#{resource} would delete #{file}")
            true
          end

          # mv
          fileutils_mock.should_receive(:mv).with(FlexMock.any, FlexMock.any).and_return do |from, to|
            Chef::Log.warn("#{resource} would move #{from} to #{to}")
            true
          end

        end
      end

      def finish(resource, action)
        flexmock_close
        Chef::Log.debug("#{resource} removed dry run mocks")
      end

      def octal_mode(mode)
        ((mode.respond_to?(:oct) ? mode.oct : mode.to_i) & 007777)
      end
    end
  end
end

