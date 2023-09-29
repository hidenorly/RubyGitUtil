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
require 'fileutils'

class ExecCommit2Patch < TaskAsync
	def initialize(srcDir, gitPath, gitOption, patchDir, verbose)
		super("ExecCommit2Patch::#{srcDir}:#{gitPath}")
		@srcDir = srcDir
		@gitPath = gitPath
		@gitOption = gitOption
		@patchDir = patchDir
		@verbose = verbose
	end

	def execute
		patchDir = "#{@patchDir}/#{RepoUtil.getFlatFilenameFromGitPath(@gitPath)}"
		FileUtil.cleanupDirectory(patchDir, true, true)

		gitPath = @srcDir+"/"+@gitPath
		if( FileTest.directory?(gitPath) ) then
			puts "\n#{gitPath}" if @verbose
			exec_cmd = ""
			exec_cmd = "git format-patch --subject-prefix=\"\" --no-numbered  #{GitUtil.getTailCommitId(gitPath)}...HEAD #{@gitOption} -o #{Shellwords.shellescape(patchDir)}"
			exec_cmd += " > #{patchDir}.log"
			exec_cmd += (@verbose ? " 2>&1" : " 2>/dev/null")

			ExecUtil.execCmd(exec_cmd, gitPath, false)
		else
			puts "\nSkipping... #{gitPath} (not existed)" if @verbose
		end
		_doneTask()
	end
end


class ExecExcludePatch < TaskAsync
	def initialize(srcDir, srcGitPath, dstDir, dstGitPath, patchDir, verbose, robustMode=True)
		super("ExecExcludePatch::#{srcGitPath}")
		@git = srcGitPath
		@srcGitPath = srcDir+"/"+srcGitPath
		@dstGitPath = dstDir+"/"+dstGitPath
		@verbose = verbose
		@patchDir = "#{patchDir}/#{RepoUtil.getFlatFilenameFromGitPath(srcGitPath)}"
		if !FileTest.directory?(@patchDir) then
			@patchDir = "#{patchDir}/#{RepoUtil.getFlatFilenameFromGitPath(dstGitPath)}"
		end
		@_commitIDs={}
		@robustMode = robustMode
	end

	def _createCache(gitPath)
		@_commitIDs = {}
		commitIDs = GitUtil.getAllCommitIdList(gitPath)
		commitIDs.each do | aCommitId |
			@_commitIDs[ aCommitId.to_s ] = true
		end
		commitIDs.clear()
	end

	def _containCommitOnBranch?(commitId)
		return @_commitIDs.has_key?(commitId)
	end

	def _isIncludedOnBranch?(gitPath, aPatchPath)
		patchBody = FileUtil.readFileAsArray(aPatchPath)
		targetCommitId = GitUtil.getCommitIdFromPatch(gitPath, patchBody, true, true, @robustMode)
		return targetCommitId ? true : false
	end

	def execute
		if FileTest.directory?(@patchDir) then
			if( FileTest.directory?(@srcGitPath) ) then
				puts "\n#{@git}:#{@patchDir}" if @verbose
				_createCache(@srcGitPath)

				patches = []
				FileUtil.iteratePath(@patchDir, "\.patch$", patches, false, false)
				patches.sort!
				patches.each do |aPatchPath|
					aCommit = GitUtil.parsePatch(aPatchPath)
					if _containCommitOnBranch?(aCommit[:id]) || _isIncludedOnBranch?(@srcGitPath, aPatchPath) then
						FileUtils.rm_f(aPatchPath)
						puts "#{aPatchPath} is removed because it's included in specified upstream" if @verbose
					end
				end
				FileUtil.removeDirectoryIfNoFile(@patchDir)
			else
				puts "\nSkipping... #{@git} (not existed)" if @verbose
			end
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

	opts.on("-s", "--source=", "Specify source repo dir.") do |src|
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

	opts.on("-o", "--output=", "Specify patch output path") do |output|
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
taskMan = ThreadPool.new( options[:numOfThreads].to_i )

targetGits.each do | srcGitPath, dstGitPath |
	taskMan.addTask( ExecCommit2Patch.new(options[:srcDir], srcGitPath, options[:srcGitOpt], options[:output], options[:verbose]) )
end

taskMan.executeAll()
taskMan.finalize()

# step - 2 : exclude existing commits in dstGitPath
taskMan = ThreadPool.new( options[:numOfThreads].to_i )

targetGits.each do | srcGitPath, dstGitPath |
	taskMan.addTask( ExecExcludePatch.new(options[:dstDir], dstGitPath, options[:srcDir], srcGitPath, options[:output], options[:verbose], true) )
end

taskMan.executeAll()
taskMan.finalize()
