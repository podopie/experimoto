Gem::Specification.new do |s|
  s.name        = 'experimoto'
  s.version     = '0.0.0'
  s.summary     = 'A tool for exotic AB testing'
  s.description = ''
  s.authors     = ['Ed Podojil', 'Carl Mackey']
  s.files       = ["lib/experimoto.rb"]
  s.homepage    = ''
  
  %w(rdbi json uuidtools).each do |g|
    s.add_dependency(g)
  end
  
  %w(rdbi-driver-sqlite3 rake).each do |g|
    s.add_development_dependency(g)
  end
end
