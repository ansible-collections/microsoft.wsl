# Copyright (c) 2023 Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)


class ModuleDocFragment:

    DOCUMENTATION = r"""
options:
  log_command_output:
    description:
      - If true, the stdout and non-fatal stderr from the WSL commands run will be logged in the standard
        stdout and stderr return values.
      - If false, the output will not be logged unless there is an error.
      - Since these modules tend to run WSL commands a lot, enabling this can add a lot of extra information
        to the module output. This is useful for debugging.
    type: bool
    default: false

attributes:
  platform:
    platforms:
      - windows
  check_mode:
    support: full
  diff_mode:
    support: full

requirements:
  - WSL installed and operational on the target host

notes:
  - Modules that parse the output of the WSL executable depend on an English output. If the language output
    by the executable is non-English, it is possible the module will not work as intended. If Microsoft introduces
    a way to set the output for the executable without affecting the rest of the operating system, this
    restriction may be removed.

seealso:
  - name: Microsoft WSL Documentation
    description: Official documentation for Windows Subsystem for Linux.
    link: https://learn.microsoft.com/en-us/windows/wsl/

"""
