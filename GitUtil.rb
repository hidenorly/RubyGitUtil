#!/usr/bin/env ruby

# Copyright 2022, 2023 hidenory
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

require "shellwords"
require_relative "ExecUtil"

class GitUtil
	def self.isGitDirectory(gitPath)
		return File.directory?("#{gitPath}/.git")
	end

	def self.isCommitId?(sha1)
		return sha1.to_s.match?(/[0-9a-f]{5,40}/)
	end

	def self.ensureSha1(sha1)
		sha= sha1.to_s.match(/[0-9a-f]{5,40}/)
		return sha ? sha[0] : nil
	end

	def self.ensureShas(shas)
		result = []
		shas.each do | aSha |
			result << ensureSha1(aSha)
		end

		return result
	end


	def self.containCommitOnBranch?(gitPath, commitId)
		return ExecUtil.hasResult?("git rev-list HEAD | grep #{commitId}", gitPath)
	end

	def self.getAllCommitIdList(gitPath)
		exec_cmd = "git rev-list HEAD"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath, true)
	end

	def self.containCommitInGit?(gitPath, commitId)
		return ExecUtil.hasResult?("git show #{commitId}", gitPath)
	end

	def self.getCommitIdList(gitPath, fromRevision=nil, toRevision=nil, gitOptions=nil)
		exec_cmd = "git log --pretty=\"%H\" --no-merges"
		if fromRevision && toRevision then
			exec_cmd += " #{fromRevision}...#{toRevision}"
		elsif fromRevision then
			exec_cmd += " #{fromRevision}"
		end
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.commitIdListOflogGrep(gitPath, key, gitOptions=nil)
		exec_cmd = "git log --pretty=\"%H\""
		exec_cmd += " --grep=#{Shellwords.shellescape(key)}" if key
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.show(gitPath, commitId, gitOptions=nil)
		exec_cmd = "git show #{commitId}"
		gitOptions = " "+gitOptions if gitOptions && !gitOptions.start_with?(":")
		exec_cmd += "#{gitOptions}" if gitOptions
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.getHeadCommitId(gitPath)
		result = nil
		exec_cmd = "git rev-list HEAD | tail -n 1"
		exec_cmd += " 2>/dev/null"

		result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
		return ensureSha1(result[0])
	end

	def self._getTailCommits(gitPath, count = 1)
		result = nil
		exec_cmd = "git rev-list HEAD | tail -n #{count}"
		exec_cmd += " 2>/dev/null"

		result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
		return ensureShas(result)
	end

	def self.getTailCommitId(gitPath)
		return _getTailCommits( gitPath, 1 )[0]
	end

	def self.getActualTailCommitId(gitPath)
		result = nil
		candidate = _getTailCommits( gitPath, 2 )
		candidate.reverse_each do | aCommitId |
			numStatResult = getLogNumStatBySha1( gitPath, aCommitId )
			if !numStatResult.empty? then
				result = aCommitId
				break
			end
		end
		return result
	end

	def self._parseNumStatOneLine(aLine, separator="#####")
		filename = ""
		aResult = {:added=>0, :removed=>0}

		if !aLine.start_with?(separator) then
			added = 0
			removed = 0

			aLine.strip!
			theResult = aLine.split(" ")
			count = 0
			theResult.each do |aResult|
				found = false
				aResult.strip!

				case count
				when 0
					added = aResult.to_i
					found = true
				when 1
					removed = aResult.to_i
					found = true
				when 2
					filename = aResult
					found = true
				else
					count = 0
				end

				count = count + 1 if found
			end


			if count == 3 then
				aResult = {:added=>added, :removed=>removed}
			else
				filename = ""
			end
		end

		return filename, aResult
	end

	def self.parseNumStatPerFile(numStatResult, separator="#####")
		result = {}

		numStatResult.each do |aLine|
			aFile, aResult = _parseNumStatOneLine(aLine, separator)


			if !aFile.empty? then
				if result.has_key?(aFile) then
					theResult = result[aFile]
					theResult[:added]   = theResult[:added] + aResult[:added]
					theResult[:removed] = theResult[:removed] + aResult[:removed]
					result[aFile] = theResult
				else
					result[aFile] = aResult
				end
			end
		end

		return result
	end

	def self._parseAuthor(aLine, separator = "#####}")
		author = ""
		pos1 = aLine.index(":", separator.length+1)
		if pos1!=nil then
			pos2 = aLine.index(":", pos1+1)
			if pos2!=nil then
				author = aLine.slice(pos1+1, pos2-pos1-1)
			end
		end
		return author
	end

	def self.parseNumStatPerAuthor(numStatResult, separator="#####")
		result = {}
		author = ""

		numStatResult.each do |aLine|
			if aLine.start_with?(separator) then
				author = _parseAuthor(aLine, separator)
			else
				aFile, aResult = _parseNumStatOneLine(aLine, separator)

				if !aFile.empty? && !author.empty? then
					if result.has_key?(author) then
						theResult = result[author]
						theResult[:added]   = theResult[:added] + aResult[:added]
						theResult[:removed] = theResult[:removed] + aResult[:removed]
						result[author] = theResult
					else
						result[author] = aResult
					end
				end
			end
		end

		return result
	end


	def self.getLogNumStat(gitPath, separator="#####", gitOptions=nil)
		exec_cmd = "git log --numstat --pretty=\"#{separator}:%h:%an:%s\""
		exec_cmd += " #{gitOptions}" if gitOptions
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.getLogNumStatBySha1(gitPath, commitId)
		exec_cmd = "git log --numstat --pretty=\"\" #{commitId}"
		exec_cmd += " 2>/dev/null"

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self.getFilesWithGitOpts(gitPath, gitOpt = "", existingFileOnly = true)
		exec_cmd = "git log --name-only --pretty=\"\" #{gitOpt ? gitOpt : ""} | sort -u"
		result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath, false, true, true)
		if existingFileOnly then
			_result = []
			result.each do |aFile|
				_result << aFile if File.exist?("#{gitPath}/#{aFile}")
			end
			result = _result
		end
		return result
	end

	def self._getValue(aLine, key)
		result = nil
		aLine = aLine.to_s
		pos = aLine.index(key)
		if pos then
			result = aLine.slice( pos+key.length, aLine.length )
			result.strip!
		end
		return result
	end

	def self._getValueFromLines(lines, key)
		lines.each do |aLine|
			result = _getValue(aLine, key)
			return result if result
		end
		return ""
	end

	def self.gitBlame(gitPath, filename, line, commitId="HEAD")
		results = {}
		exec_cmd = "git blame -p #{filename} -L #{line},#{line} #{commitId}"
		result = ExecUtil.getExecResultEachLine(exec_cmd, gitPath, false, true, true)
		if !result.empty? then
			results[:commitId] = result[0].split(" ")[0]
			results[:author] = _getValueFromLines(result, "author")
			results[:authorMail] = _getValueFromLines(result, "author-mail")
			results[:theLine] = result.last.to_s.strip
		end
		return results
	end

	# patch style
	def self.formatPatch(gitPath, commitId, outPath=nil, gitOptions=nil)
		exec_cmd = "git format-patch -1 --subject-prefix=\"\" --no-numbered --stdout #{commitId}"
		gitOptions = " "+gitOptions if gitOptions && !gitOptions.start_with?(":")
		exec_cmd += "#{gitOptions}" if gitOptions
		exec_cmd += " > #{outPath}" if outPath
		exec_cmd += " 2>/dev/null" if !exec_cmd.include?("2>")

		return ExecUtil.getExecResultEachLine(exec_cmd, gitPath)
	end

	def self._parseMbox(commit, aLine)
		result = false
		if !commit[:id] && aLine.start_with?("From ") then
			id = aLine.split(" ")
			commit[:id] = id[1] if id.length>1
		elsif !commit[:author] && aLine.start_with?("From: ") then
			commit[:author] = aLine.slice(6, aLine.length-6)
		elsif !commit[:date] && aLine.start_with?("Date: ") then
			commit[:date] = aLine.slice(6, aLine.length-6)
		elsif !commit[:title] && aLine.start_with?("Subject: ") then
			aLine = aLine.slice(9..aLine.length)
			pos = aLine.index("[PATCH")
			if pos then
				aLine = aLine.slice(pos+6..aLine.length)
				pos = aLine.index("]")
				aLine = aLine.slice(pos+1..aLine.length) if pos
				aLine.strip!
			end
			commit[:title] = aLine
		elsif commit[:title]!=nil && commit[:title].empty? then
			commit[:title] = aLine
		elsif !commit[:changedId] && aLine.start_with?("Change-Id: ") then
			commit[:changedId] = aLine.slice(11, aLine.length-11)
		elsif aLine == "---" && !commit[:modifiedFiles] then
			commit[:modifiedFiles] = []
			commit[:modifiedFilenames] = []
		else
			result = aLine.start_with?("diff --git")
			if commit[:modifiedFiles].kind_of?(Array) then
				if aLine.include?("|") then
					commit[:modifiedFiles] << aLine
					commit[:modifiedFilenames] << aLine.split("|").at(0).strip
				else
					result = true
				end
			end
		end

		return result
	end

	def self.parsePatchFromBody(theBody)
		commit = {id:nil, title:nil, date:nil, author:nil, changedId:nil, modifiedFiles:nil, modifiedFilenames:[]}

		theBody.each.each do |aLine|
			aLine = StrUtil.ensureUtf8(aLine).strip #aLine.strip!
			break if _parseMbox(commit, aLine)
		end

		return commit
	end
end
