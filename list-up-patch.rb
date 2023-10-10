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

require 'optparse'
require 'fileutils'
require_relative "RepoUtil"
require_relative "GitUtil"
require_relative 'TaskManager'
require_relative 'Reporter'


class ExecListUpPatch < TaskAsync
	def initialize(resultCollector, patchDir, verbose)
		super("ExecListUpPatch::#{patchDir}")
		@resultCollector = resultCollector
		@patchDir = patchDir
		@verbose = verbose
	end

	def execute
		result = {}
		patches = FileUtil.getRegExpFilteredFiles(@patchDir, "\.patch$")
		patches.each do |aPatch|
			aCommit = GitUtil.parsePatch(aPatch)
			if aCommit && aCommit[:id] then
				result[aPatch] = aCommit
			end
		end
		@resultCollector.onResult( @patchDir, result ) if !result.empty?

		_doneTask()
	end
end


#---- main --------------------------
options = {
	:manifestFile => RepoUtil::DEF_MANIFESTFILE,
	:verbose => false,
	:patchPath => nil,
	:repoPath => nil,
	:outputSection => "id|date|author|changedId|title",
	:numOfThreads => TaskManagerAsync.getNumberOfProcessor()
}

opt_parser = OptionParser.new do |opts|
	opts.banner = "Usage: -p patchDir"

	opts.on("-p", "--patchPath=", "Specify repo dir. (mandatory)") do |patchPath|
		options[:patchPath] = patchPath
	end

	opts.on("-r", "--repoPath=", "Specify repo dir. (optional)") do |repoPath|
		options[:repoPath] = repoPath
	end
	opts.on("-m", "--manifestFile=", "Specify manifest file (default:#{options[:manifestFile]})") do |manifestFile|
		options[:manifestFile] = manifestFile
	end

	opts.on("-o", "--outputSection=", "Specify output section (#{options[:outputSection]})") do |outputSection|
		options[:outputSection] = outputSection
	end

	opts.on("-j", "--numOfThreads=", "Specify number of threads (default:#{options[:numOfThreads]})") do |numOfThreads|
		options[:numOfThreads] = numOfThreads
	end

	opts.on("-v", "--verbose", "Enable verbose status output (default:#{options[:verbose]})") do
		options[:verbose] = true
	end

end.parse!

if !options[:patchPath] then
	puts "-p is required to set"
	exit(-1)
end

options[:patchPath] = File.expand_path(options[:patchPath])

# optional git path from repo
pathGitPath = {}
if options[:repoPath] then
	options[:repoPath] = File.expand_path(options[:repoPath]) if options[:repoPath]
	pathGitPath = RepoUtil.getGitPathesFromManifest(options[:repoPath], options[:manifestFile])
	puts pathGitPath if options[:verbose]
end

taskMan = ThreadPool.new( options[:numOfThreads].to_i )
resultCollector = ResultCollectorHash.new()

# step - 1 : iterate patch dirs
patchDirs = []
FileUtil.iteratePath(options[:patchPath], nil, patchDirs, false, true)
patchDirs << options[:patchPath] if patchDirs.empty?

patchDirs.each do | aPatchDir |
	taskMan.addTask( ExecListUpPatch.new(resultCollector, aPatchDir, options[:verbose]) )
end

taskMan.executeAll()
taskMan.finalize()

result = resultCollector.getResult()
result = result.sort

reporter = MarkdownReporter.new( options[:reportOutPath] )

result.each do | path, aResult |
	reporter.println( "" )
	reporter.titleOut( path )
	commits = []
	aResult.each do | aPatch, aCommit |
		commits << aCommit
	end
	reporter.report( commits, options[:outputSection] )
end
