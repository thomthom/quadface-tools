tags = `git tag -l`.lines.map(&:strip)

renames = tags.each_with_object({}) { |tag, hash|
  version = tag.match(/\d+\.\d+\.\d+$/)[0]
  hash[tag] = "v#{version}"
}

renames.each { |old_tag, new_tag|
  puts "Renaming #{old_tag} to #{new_tag}"
  system("git tag #{new_tag} #{old_tag}")
  system("git push --tags")
  system("git tag -d #{old_tag}")
  system("git push origin :refs/tags/#{old_tag}")
}
