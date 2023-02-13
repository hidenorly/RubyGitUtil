require "minitest/autorun"
require_relative "GitUtil"

require_relative "ExecUtil"

class TestGitUtil < Minitest::Test
	def setup
		exit() if !File.exist?(".git")
		exit() if GitUtil.getActualTailCommitId(".") != "614d5cdbf61c94ebc5691b7ba8499a394e2e6484"
	end

	def teardown
	end

	def test_isGitDirectory
		assert_equal true, GitUtil.isGitDirectory(".")
	end

	def test_getActualTailCommitId
		assert_equal "614d5cdbf61c94ebc5691b7ba8499a394e2e6484", GitUtil.getActualTailCommitId(".")
	end

	def test_test_getHeadCommitId
		assert_equal true, GitUtil.isCommitId?( GitUtil.getHeadCommitId(".") )
	end
end