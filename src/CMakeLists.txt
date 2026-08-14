set(POLKIT_NX_AGENT_SOURCES main.cpp polkitagent.cpp polkitagent.h)
qt_add_executable(${PROJECT_NAME} MANUAL_FINALIZATION ${POLKIT_NX_AGENT_SOURCES})
qt_add_qml_module(${PROJECT_NAME} URI app.maui.polkitnxagent
    NO_PLUGIN NO_IMPORT_SCAN RESOURCE_PREFIX /
    QML_FILES main.qml
    RESOURCES ../icons/user-avatar.svg)
target_link_libraries(${PROJECT_NAME} PRIVATE MauiKit4 KF6::I18n Qt6::Core Qt6::Gui Qt6::Quick Qt6::Qml PolkitQt6-1::Agent)
install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION ${KDE_INSTALL_LIBEXECDIR})
qt_finalize_target(${PROJECT_NAME})
