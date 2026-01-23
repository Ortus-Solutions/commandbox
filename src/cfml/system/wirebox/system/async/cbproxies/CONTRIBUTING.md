# cbproxies Contributing Guide

Hola amigo! I'm really excited that you are interested in contributing to our project. Before submitting your contribution, please make sure to take a moment and read through the following guidelines:

- [Code Of Conduct](#code-of-conduct)
- [Bug Reporting](#bug-reporting)
- [Support Questions](#support-questions)
- [Security Vulnerabilities](#security-vulnerabilities)
- [Language Compatibility](#language-compatibility)
- [Coding Styles \& Formatting](#coding-styles--formatting)
- [CFC Docs With DocBox](#cfc-docs-with-docbox)
- [Financial Contributions](#financial-contributions)
- [Contributors](#contributors)

## Code Of Conduct

This project is open source, and as such, the maintainers give their free time to build and maintain the source code held within. They make the code freely available in the hope that it will be of use to other developers and/or businesses. Please be considerate towards maintainers when raising issues or presenting pull requests.  **We all follow the Golden Rule: Do to others as you want them to do to you.**

- As contributors and maintainers of this project, we pledge to respect all people who contribute through reporting issues, posting feature requests, updating documentation, submitting pull requests or patches, and other activities.
- Participants will be tolerant of opposing views.
- Examples of unacceptable behavior by participants include the use of sexual language or imagery, derogatory comments or personal attacks, trolling, public or private harassment, insults, or other unprofessional conduct.
- Project maintainers have the right and responsibility to remove, edit, or reject comments, commits, code, wiki edits, issues, and other contributions that are not aligned with this Code of Conduct. Project maintainers who do not follow the Code of Conduct may be removed from the project team.
- When interpreting the words and actions of others, participants should always assume good intentions.  Emotions cannot be derived from textual representations.
- Instances of abusive, harassing, or otherwise unacceptable behavior may be reported by opening an issue or contacting one or more of the project maintainers.

## Bug Reporting

Each of the main standalone frameworks in ColdBox has its separate locations for submitting bug reports.  Please make sure also that if you submit a pull request, you link it to the appropriate issue.

https://github.com/coldbox-modules/cbproxies

If you file a bug report, your issue should contain a title, a clear description of the issue, a way to replicate the issue, and any support files that we might need to replicate your issue. The goal of a bug report is to make it easy for yourself - and others - to replicate the bug and develop a fix for it.  All issues that do not contain a way to replicate will not be addressed.

## Support Questions

If you have any questions on usage, professional support or just ideas to bounce off the maintainers, please do not create an issue.  Leverage our support channels first.

- Ortus Community Discourse: https://community.ortussolutions.com/
- Box Slack Team           : https://boxteam.ortussolutions.com/
- Professional Support     : https://www.ortussolutions.com/services/support

## Security Vulnerabilities

If you discover a security vulnerability, please send an email to the development team at [security@ortussolutions.com](mailto:security@ortussolutions.com?subject=security) and make sure you report it to the `#security` channel in our Box Team Slack Channel. All security vulnerabilities will be promptly addressed.

## Language Compatibility

Please make sure your code runs on the following CFML Engines:

- Lucee 5+
- Adobe ColdFusion 2018+

## Coding Styles & Formatting

We are big on coding styles and have included a `.cfformat.json` in the root of the project so that you can run the formatting tools and CommandBox scripts:

```bash
# Format everything
box run-script format

# Start a watcher, type away, save and auto-format for you
box run-script format: watch
```

We recommend that anytime you hack on the core you start the formatter watcher (`box run-script format:watch`). This will monitor your changes and auto-format your code for you.

You can also see the Ortus Coding Standards you must follow here: https://github.com/Ortus-Solutions/coding-standards.

## CFC Docs With DocBox

All CFCs are self-documenting and we leverage [DocBox](https://docbox.ortusbooks.com/) to document the entire software.  All functions must be properly documented using the DocBox syntax: https://docbox.ortusbooks.com/getting-started/annotating-your-code

## Financial Contributions

You can support ColdBox and all of our Open Source initiatives at Ortus Solutions by becoming a patreon.  You can also get lots of goodies and services depending on the level of contributions.

- [Become a backer or sponsor on Patreon](https://www.patreon.com/ortussolutions)
- [One-time donations via PayPal](https://www.paypal.com/paypalme/ortussolutions)

## Contributors

Thank you to all the people who have already contributed to ColdBox! We: heart: : heart: : heart: love you!

<a   href = "https://github.com/coldbox-modules/cbproxies/graphs/contributors">
<img src  = "https://contrib.rocks/image?repo=coldbox-modules/cbproxies"/>
</a>

Made with [contributors-img](https://contrib.rocks)
