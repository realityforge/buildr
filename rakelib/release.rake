WORKSPACE_DIR = File.expand_path(File.dirname(__FILE__) + '/..')

ENV['PREVIOUS_PRODUCT_VERSION'] = nil if ENV['PREVIOUS_PRODUCT_VERSION'].to_s == ''
ENV['PRODUCT_VERSION'] = nil if ENV['PRODUCT_VERSION'].to_s == ''

def in_dir(dir)
  current = Dir.pwd
  begin
    Dir.chdir(dir)
    yield
  ensure
    Dir.chdir(current)
  end
end

def stage(stage_name, description, options = {})
  if ENV['STAGE'].nil? || ENV['STAGE'] == stage_name || options[:always_run]
    puts "🚀 Release Stage: #{stage_name} - #{description}"
    begin
      yield
    rescue Exception => e
      puts '💣 Error completing stage.'
      puts "Fix the error and re-run release process passing: STAGE=#{stage_name}#{ ENV['PREVIOUS_PRODUCT_VERSION'] ? " PREVIOUS_PRODUCT_VERSION=#{ENV['PREVIOUS_PRODUCT_VERSION']}" : ''}#{ ENV['PREVIOUS_PRODUCT_VERSION'] ? " PRODUCT_VERSION=#{ENV['PRODUCT_VERSION']}" : ''}"
      raise e
    end
    ENV['STAGE'] = nil unless options[:always_run]
  elsif !ENV['STAGE'].nil?
    puts "Skipping Stage: #{stage_name} - #{description}"
  end
end

desc 'Perform a release'
task 'perform_release' do

  in_dir(WORKSPACE_DIR) do
    stage('ExtractVersion', 'Extract the version from the version constant', :always_run => true) do
      ENV['PRODUCT_VERSION'] ||= IO.read('lib/buildr/version.rb')[/VERSION = '(\d+\.\d+\.\d+)(\.dev)?'\.freeze/, 1]
      raise "Unable to extract version from lib/buildr/version.rb" unless ENV['PRODUCT_VERSION']
    end

    stage('PreReleaseUpdateVersion', 'Update the version to the non-dev version') do
      filename = 'lib/buildr/version.rb'
      content = IO.read(filename).sub(/VERSION = '(.*)'\.freeze/, "VERSION = '#{ENV['PRODUCT_VERSION']}'.freeze")
      IO.write(filename, content)
      unless `git status #{filename}`.strip.empty?
        sh "git add #{filename}"
        sh 'git commit -m "Update version in preparation for release"'
      end
    end

    stage('ZapWhite', 'Ensure that zapwhite produces no changes') do
      sh 'bundle exec zapwhite'
    end

    stage('GitClean', 'Ensure there is nothing to commit and the working tree is clean') do
      status_output = `git status -s 2>&1`.strip
      raise 'Uncommitted changes in git repository. Please commit them prior to release.' if 0 != status_output.size
    end

    stage('AddonExtensionsCheck', 'Ensure that files in addon directory do not have the .rake suffix.') do
      bad_files = FileList['addon/**/*.rake']
      raise "#{bad_files.join(', ')} named with .rake extension but should be .rb, fix them before making a release!" unless bad_files.empty?
    end

    stage('Build', 'Build the project to ensure that the tests pass') do
      sh "bundle exec rake clobber"
      sh "bundle exec rake package"
    end

    stage('TagProject', 'Tag the project') do
      sh "git tag v#{ENV['PRODUCT_VERSION']}"
    end

    stage('RubyGemsPublish', 'Publish artifacts to RubyGems.org') do
      FileList["pkg/*.gem"].each do |f|
        sh "bundle exec gem push #{f}"
      end
    end

    stage('PostReleaseUpdateVersion', 'Update the version to the non-dev version') do
      filename = 'lib/buildr/version.rb'
      parts = ENV['PRODUCT_VERSION'].split('.')
      next_version = "#{parts[0]}.#{parts[1]}.#{parts[2].to_i + 1}"
      content = IO.read(filename).sub(/VERSION = '(.*)'\.freeze/, "VERSION = '#{next_version}.dev'.freeze")
      IO.write(filename, content)
      sh "git add #{filename}"
      sh 'git commit -m "Update version in preparation for development"'
    end

    stage('PushChanges', 'Push changes to git repository') do
      sh 'git push'
      sh 'git push --tags'
    end
  end

  if ENV['STAGE']
    raise "Invalid STAGE specified '#{ENV['STAGE']}' that did not match any stage"
  end
end
