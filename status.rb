#!/usr/bin/ruby

# Copyright 2023 hidenorly
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative 'GitUtil'

all_modified, result_to_be_commited, result_changes_not_staged, result_untracked = GitUtil.status(".")
puts "All modified = #{all_modified.join("\n\t")}"
puts "To_be_commited = #{result_to_be_commited.join("\n\t")}"
puts "Changes not staged = #{result_changes_not_staged.join("\n\t")}"
puts "Untracked = #{result_untracked.join("\n\t")}"

all_modified.each do |aFile|
	result = GitUtil.diff(".", "HEAD #{aFile}")
	puts result.join("")
	puts ""
end
