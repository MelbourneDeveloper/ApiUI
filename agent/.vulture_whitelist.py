# Vulture whitelist for false positives
# See: https://github.com/jendrikseipp/vulture#ignoring-files

# Protocol method parameters (required for interface definition)
_.input_data  # _langchain_types.py - Protocol methods

# Pytest fixture dependencies (required for execution order)
_.server_process  # test fixtures - ensures server is running
_.skip_if_no_api_key  # test fixtures - ensures API key present
