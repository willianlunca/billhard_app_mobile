require 'xcodeproj'

# Abre o projeto iOS.
project = Xcodeproj::Project.open('Runner.xcodeproj')

# Localiza o target principal chamado Runner.
target = project.targets.find { |item| item.name == 'Runner' }

abort('Target Runner não encontrado.') unless target

# Localiza o grupo Runner no projeto.
runner_group = project.main_group.find_subpath('Runner', true)

files = [
  'CarPlayBridge.swift',
  'CarPlaySceneDelegate.swift'
]

files.each do |filename|
  # Evita adicionar o mesmo arquivo duas vezes.
  existing = runner_group.files.find do |file|
    file.path == filename
  end

  file_reference = existing || runner_group.new_file(filename)

  # Adiciona o arquivo à fase de compilação do target Runner,
  # somente se ele ainda não estiver nela.
  already_in_sources = target.source_build_phase.files_references.include?(
    file_reference
  )

  target.source_build_phase.add_file_reference(file_reference) unless already_in_sources
end

# Salva o project.pbxproj atualizado.
project.save

puts 'Arquivos CarPlay adicionados ao target Runner.'
