require "minitest/autorun"
require_relative "GitUtil"

require_relative "ExecUtil"

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

end