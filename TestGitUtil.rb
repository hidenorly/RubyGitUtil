#  Copyright (C) 2023 hidenorly
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


require "minitest/autorun"
require_relative "GitUtil"
require_relative "ExecUtil"
require_relative "FileUtil"

class TestGitUtil < Minitest::Test
	DEF_INITIAL_COMMIT = "614d5cdbf61c94ebc5691b7ba8499a394e2e6484" # This is for https://github.com/hidenorly/RubyGitUtil

	def setup
		exit() if !File.exist?(".git")
		exit() if GitUtil.getActualTailCommitId(".") != DEF_INITIAL_COMMIT
	end

	def teardown
	end

	def test_isGitDirectory
		assert_equal true, GitUtil.isGitDirectory(".")
	end

	def test_getTailCommitId
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getTailCommitId(".")
	end

	def test_getActualTailCommitId
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getActualTailCommitId(".")
	end

	def test_getHeadCommitId
		assert_equal true, GitUtil.isCommitId?( GitUtil.getHeadCommitId(".") )
	end

	def test_containCommitOnBranch
		assert_equal true, GitUtil.containCommitOnBranch?(".", DEF_INITIAL_COMMIT)
	end

	def test_getAllCommitIdList
		commits = GitUtil.getAllCommitIdList(".")
		assert_equal true, commits.include?(DEF_INITIAL_COMMIT)
	end

	def test_getCommitIdList
		commits = GitUtil.getCommitIdList(".", "HEAD")
		assert_equal true, commits.include?(DEF_INITIAL_COMMIT)
	end

	def test_containCommitInGit
		assert_equal true, GitUtil.containCommitInGit?(".", DEF_INITIAL_COMMIT)
	end

	def test_commitIdListOflogGrep
		assert_equal true, GitUtil.commitIdListOflogGrep(".", "getCommitIdList").include?("646182896abdefdfae854e44c074b224649d80b1")
	end

	def test_show
		result = GitUtil.show(".", DEF_INITIAL_COMMIT)
		assert_equal true, result.include?("diff --git a/README.md b/README.md")
	end

	def test_getLogNumStatBySha1_parseNumStatPerFile
		result = GitUtil.getLogNumStatBySha1(".", DEF_INITIAL_COMMIT)
		result = GitUtil.parseNumStatPerFile(result)
		assert_equal 56, result[".gitignore"][:added]
		assert_equal 0, result[".gitignore"][:removed]
		assert_equal 1, result["README.md"][:added]
		assert_equal 0, result["README.md"][:removed]
	end

	def test_getLogNumStat_parseNumStatPerAuthor
		result = GitUtil.getLogNumStat(".", "#####", DEF_INITIAL_COMMIT)
		result = GitUtil.parseNumStatPerAuthor(result)
		assert_equal 57, result["hidenorly"][:added]
		assert_equal 0, result["hidenorly"][:removed]
	end

	def test_getFilesWithGitOpts
		result = GitUtil.getFilesWithGitOpts(".", DEF_INITIAL_COMMIT)
		assert_equal true, result.include?("README.md")
		assert_equal true, result.include?(".gitignore")
	end

	def test_gitBlame
		result = GitUtil.gitBlame(".", "README.md", 1, DEF_INITIAL_COMMIT)
		assert_equal DEF_INITIAL_COMMIT, result[:commitId]
		assert_equal "hidenorly", result[:author]
		assert_equal "<hidenorly@users.noreply.github.com>", result[:authorMail]
		assert_equal "# RubyGitUtil", result[:theLine]
	end

	def test_formatPatchAndParsePatchFromBody
		result = GitUtil.formatPatch(".", DEF_INITIAL_COMMIT )
		assert_equal true, result.include?("Subject: Initial commit")

		theCommit = GitUtil.parsePatchFromBody(result)
		assert_equal DEF_INITIAL_COMMIT, theCommit[:id]
		assert_equal "Initial commit", theCommit[:title]
		assert_equal "Mon, 13 Feb 2023 02:54:47 +0900", theCommit[:date]
		assert_equal "hidenorly <hidenorly@users.noreply.github.com>", theCommit[:author]
		assert_nil theCommit[:changedId]
		assert_equal true, theCommit[:modifiedFilenames].include?("README.md")
		assert_equal true, theCommit[:modifiedFilenames].include?(".gitignore")
	end

	DEF_TMP_FILE = "tmpPatch.mbox"
	def test_parsePatch
		result = GitUtil.formatPatch(".", DEF_INITIAL_COMMIT )
		FileUtil.writeFile(DEF_TMP_FILE, result)

		theCommit = GitUtil.parsePatch(DEF_TMP_FILE)
		assert_equal DEF_INITIAL_COMMIT, theCommit[:id]
		assert_equal "Initial commit", theCommit[:title]
		assert_equal "Mon, 13 Feb 2023 02:54:47 +0900", theCommit[:date]
		assert_equal "hidenorly <hidenorly@users.noreply.github.com>", theCommit[:author]
		assert_nil theCommit[:changedId]
		assert_equal true, theCommit[:modifiedFilenames].include?("README.md")
		assert_equal true, theCommit[:modifiedFilenames].include?(".gitignore")

		FileUtils.rm_f(DEF_TMP_FILE)
	end

	def test_isSamePatch
		result1 = GitUtil.formatPatch(".", DEF_INITIAL_COMMIT )
		result2 = result1.clone()
		result2.each{ |aLine| aLine.gsub!(DEF_INITIAL_COMMIT, "xxx") }
		result2.each{ |aLine| aLine.gsub!("hidenorly", "hoge") }
		stream1 = ArrayStream.new( result1 )
		stream2 = ArrayStream.new( result2 )

		assert_equal true, GitUtil.isSamePatch?( stream1, stream2 )
		assert_equal true, GitUtil.isSamePatch?( stream1, stream2, true )

		result3 = GitUtil.formatPatch(".", "HEAD")
		stream3 = ArrayStream.new( result3 )
		assert_equal false, GitUtil.isSamePatch?( stream1, stream3 )
	end

	def test_containCommitOnBranch
		assert_equal true, GitUtil.containCommitOnBranch?(".", DEF_INITIAL_COMMIT)
	end

	def test_containCommitInGit
		assert_equal true, GitUtil.containCommitInGit?(".", DEF_INITIAL_COMMIT)
	end

	def test_getCommitIdFromPatch
		patchBody = GitUtil.formatPatch(".", DEF_INITIAL_COMMIT)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody, false)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody, false, true)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody, false, true, true)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody, false, true, false)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody, false, false, true)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody, false, false, false)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody, true, false, true)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody, true, false, false)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody, true, true, true)
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getCommitIdFromPatch(".", patchBody, true, true, false)
	end

	def test_getBranchPoint
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getBranchPoint(".", "main", "../RubyFileUtil", "main")
	end

	def test_checkoutAndUndoCheckout
		# testcase for sha1 specified checkout
		headId = GitUtil.getHeadCommitId(".")
		GitUtil.checkout(".", DEF_INITIAL_COMMIT)
		GitUtil.undoCheckout(".")
		assert_equal headId, GitUtil.getHeadCommitId(".")

		# TODO: testcase for checkout with branch
	end

	def test_am_apply
		result = GitUtil.formatPatch(".", "HEAD")
		FileUtil.writeFile(DEF_TMP_FILE, result)

		assert_equal false, GitUtil.am(".", DEF_TMP_FILE)
		GitUtil.amAbort(".")

		assert_equal false, GitUtil.apply(".", DEF_TMP_FILE)
		GitUtil.amAbort(".")

		#TODO: test case for applyable case... (another test git repository is necessary)

		FileUtils.rm_f(DEF_TMP_FILE)
	end

	def test_cherryPick
		assert_equal true, GitUtil.cherryPick(".", "HEAD")
		GitUtil.cherryPickAbort(".")
	end

	def test_reset
		commits = GitUtil.getAllCommitIdList(".")
		GitUtil.reset(".", DEF_INITIAL_COMMIT)
		commits2 = GitUtil.getAllCommitIdList(".")
		assert_equal DEF_INITIAL_COMMIT, commits2[0]
		GitUtil.reset(".", commits[0])
		commits3 = GitUtil.getAllCommitIdList(".")
		assert_equal commits, commits3
	end

	def test_revert
		commits = GitUtil.getAllCommitIdList(".")
		result = GitUtil.revert(".", DEF_INITIAL_COMMIT)
		if !result then
			commits2 = GitUtil.getAllCommitIdList(".")
			assert_equal commits, commits2
			GitUtil.revertAbort(".")
			commits2 = GitUtil.getAllCommitIdList(".")
			assert_equal commits, commits2
		end
		GitUtil.reset(".", commits[0], "--merge")
		commits3 = GitUtil.getAllCommitIdList(".")
		assert_equal commits, commits3
	end

	DEF_TEMP_ARCHIVE="archive.tar"
	def test_archive
		GitUtil.archive(".", DEF_TEMP_ARCHIVE)
		result = ExecUtil.getExecResultEachLine("tar -tf #{DEF_TEMP_ARCHIVE}")
=begin
		files = FileUtil.getRegExpFilteredFiles(".", nil)
		_files = []
		files.each do | aFile |
			_files << FileUtil.getFilenameFromPath(aFile)
		end
=end
		_files = GitUtil.getFilesWithGitOpts(".")
		isSuccess = true
		result.each do |aFile|
			isSuccess = _files.include?(aFile)
			break if !isSuccess
		end
		assert_equal true, isSuccess
		FileUtils.rm(DEF_TEMP_ARCHIVE)
	end

	def test_isCommitExistWithFileAndGitOpts
		assert_equal true, GitUtil.getFilesWithGitOpts(".", "--author=twitte.harold@gmail.com").include?("GitUtil.rb")
	end

	def test_isCommitExistWithFileAndGitOpts
		assert_equal true, GitUtil.isCommitExistWithFileAndGitOpts(".", "GitUtil.rb")
	end

	DEF_TEMPFILE = "_tempfile.txt"
	def test_statusAndAddAndUnstange
		if File.exist?(DEF_TEMPFILE) then
			puts "Please execute test case after clean condition on git status"
		else
			FileUtil.writeFile(DEF_TEMPFILE, ["hello"])

			all_modified, result_to_be_commited, result_changes_not_staged, result_untracked = GitUtil.status(".")
			assert_equal true, all_modified.include?(DEF_TEMPFILE)
			assert_equal false, result_to_be_commited.include?(DEF_TEMPFILE)
			assert_equal false, result_changes_not_staged.include?(DEF_TEMPFILE)
			assert_equal true, result_untracked.include?(DEF_TEMPFILE)

			# Add git add and check status...
			GitUtil.add(".", [DEF_TEMPFILE])
			all_modified, result_to_be_commited, result_changes_not_staged, result_untracked = GitUtil.status(".")
			assert_equal true, all_modified.include?(DEF_TEMPFILE)
			assert_equal true, result_to_be_commited.include?(DEF_TEMPFILE)
			assert_equal false, result_changes_not_staged.include?(DEF_TEMPFILE)
			assert_equal false, result_untracked.include?(DEF_TEMPFILE)

			# git restore
			GitUtil.unstange(".", [DEF_TEMPFILE])
			all_modified, result_to_be_commited, result_changes_not_staged, result_untracked = GitUtil.status(".")
			assert_equal true, all_modified.include?(DEF_TEMPFILE)
			assert_equal false, result_to_be_commited.include?(DEF_TEMPFILE)
			assert_equal false, result_changes_not_staged.include?(DEF_TEMPFILE)
			assert_equal true, result_untracked.include?(DEF_TEMPFILE)

			FileUtils.rm(DEF_TEMPFILE)
		end
	end
end