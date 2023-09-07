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
require_relative 'ExecUtil'
require_relative 'TaskManager'
require_relative "RepoUtil"

class ExecCommit2Patch < TaskAsync
	def initialize(srcDir, path, gitPath, gitOption, patchDir, options)
		super("ExecCommit2Patch::#{srcDir}:#{path}:#{gitPath}")
		@srcDir = srcDir
		@path = path
		@gitPath = gitPath
		@gitOption = gitOption
		@patchDir = patchDir
		@options = options
	end

	def execute
		patchDir = "#{@patchDir}/#{RepoUtil.getFlatFilenameFromGitPath(@gitPath)}"
		FileUtil.cleanupDirectory(patchDir, true, true)

		gitPath = @srcDir+"/"+@path
		if( FileTest.directory?(gitPath) ) then
			puts "\n#{gitPath}" if @options[:verbose]
			exec_cmd = ""
			exec_cmd = "git format-patch --subject-prefix=\"\" --no-numbered  #{GitUtil.getTailCommitId(gitPath)}...HEAD #{@gitOption} -o #{Shellwords.shellescape(patchDir)}"
			exec_cmd += " > #{patchDir}.log"
			exec_cmd += (@options[:verbose] ? " 2>&1" : " 2>/dev/null")

			ExecUtil.execCmd(exec_cmd, gitPath, false)
		else
			puts "\nSkipping... #{gitPath} (not existed)" if @options[:verbose]
		end
		_doneTask()
	end
end




#---- main --------------------------
options = {
	:manifestFile => RepoUtil::DEF_MANIFESTFILE,
	:logDirectory => Dir.pwd,
	:disableLog => false,
	:verbose => false,
	:srcDir => nil,
	:srcGitOpt => "",
	:dstDir => ".",
	:dstGitOpt => "",
	:gitPath => nil,
	:output => ".",
	:numOfThreads => TaskManagerAsync.getNumberOfProcessor()
}

opt_parser = OptionParser.new do |opts|
	opts.banner = "Usage: -s sourceRepoDir -t targetRepoDir"

	opts.on("-s", "--source=", "Specify source repo dir. if you want to exec as delta/new files") do |src|
		options[:srcDir] = src
	end

	opts.on("", "--sourceGitOpt=", "Specify gitOpt for source repo dir.") do |srcGitOpt|
		options[:srcGitOpt] = srcGitOpt
	end

	opts.on("-t", "--target=", "Specify target repo dir.") do |dst|
		options[:dstDir] = dst
	end

	opts.on("-g", "--gitPath=", "Specify target git path (regexp) if you want to limit to execute the git only") do |gitPath|
		options[:gitPath] = gitPath
	end

	opts.on("-o", "--output=", "Specify output path )") do |output|
		options[:output] = output
	end

	opts.on("", "--manifestFile=", "Specify manifest file (default:#{options[:manifestFile]})") do |manifestFile|
		options[:manifestFile] = manifestFile
	end

	opts.on("-j", "--numOfThreads=", "Specify number of threads (default:#{options[:numOfThreads]})") do |numOfThreads|
		options[:numOfThreads] = numOfThreads
	end

	opts.on("-v", "--verbose", "Enable verbose status output (default:#{options[:verbose]})") do
		options[:verbose] = true
	end

end.parse!

options[:srcDir] = File.expand_path(options[:srcDir]) if options[:srcDir]
options[:dstDir] = File.expand_path(options[:dstDir])

# common
taskMan = ThreadPool.new( options[:numOfThreads].to_i )

if ( options[:srcDir] && !RepoUtil.isRepoDirectory?(options[:srcDir]) ) then
	puts "-s #{options[:srcDir]} is not repo directory"
	exit(-1)
end

if ( !RepoUtil.isRepoDirectory?(options[:dstDir]) ) then
	puts "-t #{options[:dstDir]} is not repo directory"
	exit(-1)
end

targetGits = RepoUtil.getMatchedGitsWithFilter( options[:dstDir], options[:manifestFile], options[:gitPath] )
if options[:srcDir] && options[:dstDir] then
	matched, missed = RepoUtil.getRobustMatchedGitsWithFilter( options[:srcDir], options[:dstDir], options[:manifestFile], options[:gitPath])
	targetGits = matched
end

# step - 1 : convert commit to .patch
targetGits.each do | path, gitPath |
	taskMan.addTask( ExecCommit2Patch.new(options[:srcDir], path, gitPath, options[:srcGitOpt], options[:output], options) )
end

taskMan.executeAll()
taskMan.finalize()
