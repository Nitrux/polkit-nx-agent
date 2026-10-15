project('polkit-nx-agent', 'cpp', version: '0.1.0', meson_version: '>=1.0.0', default_options: ['cpp_std=c++17', 'buildtype=release'])
qt6 = import('qt6')
qt = dependency('qt6', version: '>=6.9', modules: ['Core', 'Gui', 'Qml', 'Quick'])
cpp_compiler = meson.get_compiler('cpp')
kf6_core = dependency('KF6CoreAddons', version: '>=6.13')
kf6_i18n = declare_dependency(
    include_directories: include_directories(get_option('prefix') / 'include' / 'KF6' / 'KI18n'),
    dependencies: [cpp_compiler.find_library('KF6I18n'), cpp_compiler.find_library('KF6I18nQml')],
)
mauikit = dependency('MauiKit4', version: '>=4.0.5')
polkit = declare_dependency(
    include_directories: include_directories(get_option('prefix') / 'include' / 'polkit-qt6-1'),
    dependencies: [
        cpp_compiler.find_library('polkit-qt6-agent-1'),
        cpp_compiler.find_library('polkit-qt6-core-1'),
    ],
)
cpp_args = []
if host_machine.cpu_family() == 'x86_64'
    cpp_args += ['-march=x86-64-v3']
endif
qt_sources = qt6.preprocess(qresources: 'src/qml.qrc', moc_headers: ['src/polkitagent.h'])
executable('polkit-nx-agent', ['src/main.cpp', 'src/polkitagent.cpp'] + qt_sources, dependencies: [qt, kf6_core, kf6_i18n, mauikit, polkit], cpp_args: cpp_args, install: true, install_dir: get_option('libexecdir'))
