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

	def test_getActualTailCommitId
		assert_equal DEF_INITIAL_COMMIT, GitUtil.getActualTailCommitId(".")
	end

	def test_getHeadCommitId
		assert_equal true, GitUtil.isCommitId?( GitUtil.getHeadCommitId(".") )
	end

	def test_containCommitOnBranch
		assert_equal true, GitUtil.containCommitOnBranch?(".", DEF_INITIAL_COMMIT)
	end
end