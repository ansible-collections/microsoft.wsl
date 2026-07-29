# Ansible Collection: microsoft.wsl

This repo hosts the `microsoft.wsl` Ansible Collection.

The **microsoft.wsl** collection enables the management of Windows Subsystem for Linux (WSL) using Ansible. This collection brings forward the possibility to manage WSL distributions and automate operator tasks on Windows systems.

System programmers can enable pipelines to setup, configure and manage WSL distributions while system administrators can automate time consuming repetitive tasks inevitably freeing up their time. New WSL users can find comfort in Ansible's familiarity and expedite their proficiency in record time.


## Requirements

The content in this collection is mainly designed to run on a Windows target. The target must have Powershell installed.

There are no special requirements for the Ansible controller to run this content.

### Ansible version compatibility

This collection has been tested against following Ansible versions: **>=2.16.0**.

### Windows Compatibility

This collection supports Windows 10 and later, as well as Windows Server 2019 and later.


## Installation

Before using this collection, you need to install it with the Ansible Galaxy command-line tool:

```sh
ansible-galaxy collection install microsoft.wsl
```

You can also include it in a requirements.yml file and install it with `ansible-galaxy collection install -r requirements.yml`, using the format:

```sh
collections:
  - name: microsoft.wsl
```

Note that if you install the collection from Ansible Galaxy, it will not be upgraded automatically when you upgrade the Ansible package.
To upgrade the collection to the latest available version, run the following command:

```sh
ansible-galaxy collection install microsoft.wsl --upgrade
```

You can also install a specific version of the collection, for example, if you need to install a different version. Use the following syntax to install version 1.0.0:

```sh
ansible-galaxy collection install microsoft.wsl:1.0.0
```


## Use Cases

* Use Case Name: Manage WSL Distributions
  * Actors:
    * System Admin
  * Description:
    * A systems administrator can create, configure and manage WSL distributions on Windows hosts.
  * Flow:
    * Install and configure WSL distributions (`microsoft.wsl.distribution`)
    * Manage WSL distribution settings and configurations (`microsoft.wsl.distribution_config`)
    * Export and import distributions for backup or migration (`microsoft.wsl.export`, `microsoft.wsl.import`)
    * Run commands inside WSL distributions (`microsoft.wsl.command`)

* Use Case Name: Gather Information About WSL Resources
  * Actors:
    * System Admin
  * Description:
    * The system administrator can gather detailed information about WSL distributions and their configurations for reporting.
  * Flow:
    * Gather details about installed WSL distributions (`microsoft.wsl.distribution_info`)
    * Gather WSL configuration and version information (`microsoft.wsl.status_info`)
    * Gather distribution-level configuration from wsl.conf (`microsoft.wsl.distribution_config_info`)


## Testing

[![Ansible Test](https://github.com/ansible-collections/microsoft.wsl/actions/workflows/integration-test.yml/badge.svg)](https://github.com/ansible-collections/microsoft.wsl/actions/workflows/integration-test.yml)

Static analysis and coverage are tracked on [SonarCloud](https://sonarcloud.io/project/overview?id=ansible-collections_microsoft.wsl). See [docs/sonarcloud.md](docs/sonarcloud.md) for CI wiring and contributor notes.

All releases will meet the following test criteria.

* 100% success for [Integration](https://github.com/ansible-collections/microsoft.wsl/blob/main/tests/integration) tests.
* 100% success for [Unit](https://github.com/ansible-collections/microsoft.wsl/blob/main/tests/unit) tests.
* 100% success for [Sanity](https://docs.ansible.com/ansible/latest/dev_guide/testing/sanity/index.html#all-sanity-tests) tests as part of [ansible-test](https://docs.ansible.com/ansible/latest/dev_guide/testing.html#run-sanity-tests).
* 100% success for [ansible-lint](https://ansible.readthedocs.io/projects/lint/) allowing only false positives.


## Contributing

This community is currently accepting contributions. We encourage you to open [git issues](https://github.com/ansible-collections/microsoft.wsl/issues) for bugs, comments or feature requests. Please feel free to submit a PR to resolve the issue.

Refer to the [Ansible community guide](https://docs.ansible.com/ansible/devel/community/index.html).


## Communication

* Join the Ansible forum:
  * [Get Help](https://forum.ansible.com/c/help/6): get help or help others.
  * [Posts tagged with 'wsl'](https://forum.ansible.com/tag/wsl): subscribe to participate in collection-related conversations.
  * [Posts tagged with 'windows'](https://forum.ansible.com/tag/windows): subscribe to participate in Windows-related conversations.
  * [Social Spaces](https://forum.ansible.com/c/chat/4): gather and interact with fellow enthusiasts.
  * [News & Announcements](https://forum.ansible.com/c/news/5): track project-wide announcements including social events.

* The Ansible [Bullhorn newsletter](https://docs.ansible.com/ansible/devel/community/communication.html#the-bullhorn): used to announce releases and important changes.

For more information about communication, see the [Ansible communication guide](https://docs.ansible.com/ansible/devel/community/communication.html).


## Support

As Red Hat Ansible Certified Content, this collection is entitled to support through the Ansible Automation Platform (AAP) using the **Create issue** button on the top right corner.

If a support case cannot be opened with Red Hat and the collection has been obtained either from Galaxy or GitHub, there may community help available via:
- GitHub issues for bugs or feature requests: https://github.com/ansible-collections/microsoft.wsl/issues
- the [Ansible Forum](https://forum.ansible.com/) for general inqueries or workflow questions

## Release Notes and Roadmap

A list of available releases can be found on the github [release page](https://github.com/ansible-collections/microsoft.wsl/releases).
A changelog may be found attached to the release, or in the [CHANGELOG.rst](https://github.com/ansible-collections/microsoft.wsl/blob/main/CHANGELOG.rst)

Note, some collections release before an ansible-core version reaches End of Life (EOL), thus the version of ansible-core that is supported must be a version that is currently supported.
For AAP users, to see the supported ansible-core versions, review the [AAP Life Cycle](https://access.redhat.com/support/policy/updates/ansible-automation-platform).
For Galaxy and GitHub users, to see the supported ansible-core versions, review the [ansible-core support matrix](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html#ansible-core-support-matrix).


## Related Information

The `ansible.windows` collection offers additional Windows automation functionality.
The `community.windows` collection offers additional community supported Windows functionality.


## License Information

GNU General Public License v3.0 or later
See [LICENSE](https://github.com/ansible-collections/microsoft.wsl/blob/main/LICENSE) to see the full text.
