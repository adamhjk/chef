#
# Author:: Michael Leinartas (<mleinartas@gmail.com>)
# Copyright:: Copyright (c) 2010 Michael Leinartas
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

require 'spec_helper'

describe Chef::Resource::Ohai do

  before(:each) do
    @resource = Chef::Resource::Ohai.new("ohai_reload")
  end

  it "should create a new Chef::Resource::Ohai" do
    expect(@resource).to be_a_kind_of(Chef::Resource)
    expect(@resource).to be_a_kind_of(Chef::Resource::Ohai)
  end

  it "should have a resource name of :ohai" do
    expect(@resource.resource_name).to eql(:ohai)
  end

  it "should have a default action of create" do
    expect(@resource.action).to eql(:reload)
  end

  it "should allow you to set the plugin attribute" do
    @resource.plugin "passwd"
    expect(@resource.plugin).to eql("passwd")
  end

  describe "when it has a plugin value" do
    before do
      @resource.name("test")
      @resource.plugin("passwd")
    end

    it "describes its state" do
      state = @resource.state
      expect(state[:plugin]).to eq("passwd")
    end

    it "returns the name as its identity" do
      expect(@resource.identity).to eq("test")
    end
  end


end
