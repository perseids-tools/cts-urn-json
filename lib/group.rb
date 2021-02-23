require_relative './shell'

class Group
  include Shell

  def initialize(group, tmp)
    @group = group
    @tmp = tmp
  end

  def init!
    directory_name = s(File.join(tmp, group[:name]))
    `mkdir -p #{directory_name}`

    each_repo do |_repo, name, commit, url|
      `cd #{directory_name} && git clone #{url} #{name}`
      `cd #{name} && git checkout #{commit}`
    end
  end

  def update!
    each_repo do |repo, name|
      `cd #{name} && git fetch && git reset --hard origin/HEAD`
      sha = `cd #{name} && git rev-parse HEAD`.chomp

      repo[:commit] = sha
    end
  end

  def sync!
    each_repo do |_repo, name, commit|
      `cd #{name} && git fetch && git checkout #{commit}`
    end
  end

  private

  attr_reader :group, :tmp

  def each_repo
    group[:git].each do |repo|
      name = s(File.join(tmp, group[:name], repo[:name]))
      url = s(repo[:url])
      commit = s(repo[:commit])

      yield repo, name, commit, url
    end
  end
end
