#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Christopher Walters (<cw@opscode.com>)
# Copyright:: Copyright (c) 2008, 2009 Opscode, Inc.
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

      def amnesia(&block)
        lm = flexmock_created_mocks
        flexmock_close
        r = block.call
        lm.each do |mo| 
          flexmock_remember(mo)
        end
        r
      end

      def start(resource, action)
        Chef::Log.debug("#{resource} initializing dry run mocks")
        file_mocks(resource, action)
        fileutils_mocks(resource, action)
        tempfile_mocks(resource, action)
      end

      def tempfile_mocks(resource, action)
        flexmock(Tempfile, "Tempfile Class") do |tempfile_mock|
          tempfile_mock.should_receive(:open).with(String).and_return do |arg|
            Chef::Log.debug("#{resource} opened a tempfile")
            amnesia { Tempfile.open(arg) }
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
            amnesia { File.open(filename, mode) }
          end
          file_mock.should_receive(:open).with(String, "rb").and_return do |filename, mode|
            Chef::Log.debug("#{resource} opened file #{filename} with mode #{mode}")
            amnesia { File.open(filename, mode) }
          end
          file_mock.should_receive(:open).with(String, "r", Proc).and_return do |filename, mode, block|
            Chef::Log.debug("#{resource} opened file #{filename} with mode #{mode}")
            amnesia { block.call(File.open(filename, mode)) }
          end
          file_mock.should_receive(:open).with(String, "rb", Proc).and_return do |filename, mode, block|
            Chef::Log.debug("#{resource} opened file #{filename} with mode #{mode}")
            amnesia { block.call(File.open(filename, mode)) }
          end

          # File writing
          file_mock.should_receive(:open).with(String, "w+", Proc).and_return do |filename, mode, filehandle_block|
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
            Chef::Log.warn("#{resource} would overwrite file at #{filename}")
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
        end
      end

      def fileutils_mocks(resource, action)
        flexmock(FileUtils, "FileUtils Class") do |fileutils_mock|
          # Directory creation
          fileutils_mock.should_receive(:mkdir_p).with(String).and_return do |dir|
            Chef::Log.warn("#{resource} would create directory #{dir}")
            true
          end

          # File copies
          fileutils_mock.should_receive(:cp).with(String, String, Hash).and_return do |from, to, options|
            Chef::Log.warn("#{resource} would copy #{from} to #{to}")
            true
          end
          fileutils_mock.should_receive(:cp).with(String, String).and_return do |from, to|
            Chef::Log.warn("#{resource} would copy #{from} to #{to}")
            true
          end

          # File deletion
          fileutils_mock.should_receive(:rm).with(String).and_return do |file|
            Chef::Log.warn("#{resource} would delete #{file}")
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

