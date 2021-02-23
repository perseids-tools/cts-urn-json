module Shell
  private

  def s(string)
    Shellwords.escape(string)
  end
end
