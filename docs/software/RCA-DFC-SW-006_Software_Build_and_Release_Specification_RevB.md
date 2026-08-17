**ROYAL CUBIT AEROSPACE**

**DRAGON CORE™**

**SOFTWARE BUILD AND RELEASE  
SPECIFICATION**

| Field | Value |
|---|---|
| Document Number | RCA-DFC-SW-006 |
| Revision | B |
| Status | Technical Baseline |
| Product | Dragon Core™ Revision A |
| Program | Dragon Flight™ Core ASIC Development Program |
| Organization | Royal Cubit Aerospace |
| Release Date | 2026-08-07 |

# Revision History

| Revision | Date | Description | Author |
|---|---|---|---|
| A | Undated | Historical initial baseline supplied as reference only | Royal Cubit Aerospace |
| B | 2026-08-07 | Rebuilt beneath the eight controlling specifications for external-host software build, packaging, release, deployment, and archival | Royal Cubit Aerospace |

# Approval

| Role | Name | Signature | Date |
|---|---|---|---|
| Prepared By |  |  |  |
| Reviewed By |  |  |  |
| Approved By |  |  |  |

# Table of Contents

1. Purpose
2. Scope
3. Applicable Documents
4. Build Configuration Item Identification
5. Build and Release Philosophy
6. Software Lifecycle Overview
7. Software Configuration Management Overview
8. Source Code Repository Requirements
9. Repository Organization
10. Branching Strategy
11. Version Numbering Policy
12. Release Identification
13. Development Build Process
14. Integration Build Process
15. Release Build Process
16. Build Environment Requirements
17. Supported Development Platforms
18. Compiler Toolchain Requirements
19. Linker Configuration
20. Build System Architecture
21. Build Configuration Profiles
22. Dependency Management
23. Third-Party Software Management
24. Build Automation
25. Continuous Integration Build Pipeline
26. Build Verification
27. Build Reproducibility Requirements
28. Firmware Image Generation
29. FPGA Software Package Generation
30. ASIC Software Package Generation
31. Binary Packaging Requirements
32. Library Packaging Requirements
33. Installation Package Generation
34. Release Metadata
35. Version Manifest Requirements
36. Digital Signature Requirements
37. Checksum Requirements
38. Release Documentation
39. Release Notes Requirements
40. Deployment Procedures
41. Rollback Procedures
42. Verification Integration
43. Quality Gates
44. Release Approval Process
45. Configuration Audits
46. Archive Requirements
47. Long-Term Retention Requirements
48. Security Requirements
49. Traceability Requirements
50. Deliverables
51. Exit Criteria
52. Baseline Statement

# 1. Purpose

## 1.1 Purpose of this Specification

This Software Build and Release Specification establishes the mandatory requirements for identifying, generating, compiling, linking, analyzing, testing, packaging, approving, distributing, deploying, rolling back, archiving, and reproducing Dragon Flight software that supports Dragon Core Revision A from outside the fabricated device.

Dragon Core is a processor-free digital ASIC. It contains no processor, firmware, bootloader, operating system, executable memory, software runtime, HAL, BSP, driver, middleware, stack, heap, or application. All executable software governed by this specification runs on an external host or in an external development, verification, manufacturing, or maintenance environment.

This specification is subordinate to the eight controlling technical specifications identified by `RCA-DFC-CHTR-002`, Section 3.1. It governs the software build-and-release lifecycle and shall not redefine product scope, responsibility allocation, device behavior, internal hardware architecture, register meaning, controlling verification, controlling trace relationships, or RTL implementation rules.

## 1.2 Engineering Objectives

- produce deterministic and reviewable build results from controlled inputs;
- preserve one authoritative source for every device-facing definition;
- prevent stale generated artifacts, unapproved dependencies, and engineering-only capabilities from entering production releases;
- bind every released artifact and item of evidence to one complete manifest;
- support independent reproduction, audit, rollback, and long-term maintenance; and
- preserve the separation between external-host software identity and Dragon Core hardware identity.

## 1.3 Applicability

This specification applies to every software configuration item, generator, generated host artifact, test program, build script, tool configuration, external embedded-host image, library, application, installer, platform package, release record, and software evidence package delivered or used for release credit by Royal Cubit Aerospace.

## 1.4 Relationship to Other Specifications

`RCA-DFC-SW-001` defines software architecture; `RCA-DFC-SW-002` defines external embedded-host firmware; `RCA-DFC-SW-003` defines HAL, driver, and BSP APIs; `RCA-DFC-SW-004` defines coding rules; and `RCA-DFC-SW-005` defines software verification and validation. This specification consumes those definitions and owns only their build, packaging, release, deployment, rollback, and archival realization.

## 1.5 Compliance

`SWBR-DOC-001` — No artifact shall be represented as an approved software release unless every applicable requirement and exit criterion of this specification is satisfied for the exact released configuration.

`SWBR-DOC-002` — A build script, manifest, generated file, package, example, or release record shall not become an alternate authority for a technical fact owned by a controlling or governing software specification.

`SWBR-DOC-003` — A conflict, ambiguity, omission, or incomplete definition shall be flagged to its normative owner and shall block the affected build or release claim until corrected or formally excluded from the claimed scope.

## Table 1-1. Purpose and Build Objectives

| Objective | Required outcome |
|---|---|
| Reproducibility | Controlled inputs regenerate equivalent artifacts. |
| Integrity | Artifacts, manifests, signatures, and evidence agree. |
| Authority preservation | Generated content derives from its normative owner. |
| Isolation | Production artifacts exclude engineering-only capabilities. |
| Traceability | Every released item resolves to source, build, verification, and approval records. |
| Recoverability | Prior approved releases can be restored and redeployed. |

# 2. Scope

## 2.1 Scope of this Specification

This specification governs software source baselines, generated artifacts, external-host executables, static and shared libraries, BSPs, HALs, drivers, services, applications, tools, configuration schemas, installers, platform packages, documentation, manifests, verification evidence, release approvals, deployment records, and archives.

## 2.2 Software Components Covered

Covered components include external embedded-host firmware; portable HAL and driver code; target BSPs; Dragon SDK libraries; Dragon Console™, Dragon Gateway™, and Dragon Sentinel™; configuration, diagnostic, persistence, recovery, manufacturing, FPGA-validation, HIL, post-silicon, and maintenance software; generators; generated host definitions; and supporting automation.

## 2.3 Build Activities Included

Included activities are source and dependency resolution, generation, compilation, assembly where applicable, external-host linking, analysis, tests, packaging, metadata generation, integrity protection, approval, distribution, deployment, rollback, audit, archive, restoration, and release reproduction.

## 2.4 Activities Outside the Scope

This specification does not own:

- physical ASIC integration, OpenFrame selection details, PDK selection, package mapping, scan insertion, or physical signoff;
- RTL behavior, RTL coding rules, FPGA bitstream construction, ASIC netlist construction, or device-verification acceptance criteria;
- board, aircraft, external transceiver, power-drive, wiring, installation-certification, or operational-authorization activities;
- software requirements, API behavior, coding rules, or verification methods already owned by `RCA-DFC-SW-001` through `RCA-DFC-SW-005`; or
- installation-specific aircraft policy, calibration, credentials, or operational data.

Hardware implementation artifacts may be identified and packaged with software for a controlled validation or bring-up configuration, but their construction and technical acceptance remain with their applicable hardware, integration, and Verification Plan owners.

## 2.5 Build Objectives

`SWBR-SCOPE-001` — The build shall transform only identified, approved inputs into identified outputs without undocumented manual intervention.

`SWBR-SCOPE-002` — Software packaging shall preserve device, platform, board, software, and verification ownership boundaries defined by `RCA-DFC-PBIO-002`.

## 2.6 Applicability

Requirements apply according to configuration-item type and release class. A requirement marked not applicable shall have a recorded technical basis, affected scope, approver, and verification impact.

## 2.7 Revision B Scope

Revision B replaces every historical assumption of ASIC-local firmware, processor boot memory, direct Dragon Core MMIO, a Dragon Core target linker map, or software installation into the device. The terms firmware image, FPGA software package, and ASIC software package in Sections 28 through 30 refer only to external-host software and associated external evidence.

## Table 2-1. Scope Summary

| Included | Excluded |
|---|---|
| External-host software and build tooling | Executable software inside Dragon Core |
| Generated host bindings and provenance | Hand-maintained copies of device definitions |
| Software release and evidence packages | Ownership of RTL or physical ASIC acceptance |
| External-host deployment and rollback | Programming a software image into Dragon Core |
| Identification of associated hardware images | Construction authority for FPGA/ASIC hardware artifacts |

# 3. Applicable Documents

## 3.1 Purpose

Applicable documents provide the normative inputs consumed by the build and release process. Revision identifiers and content digests used by a release shall be recorded in its manifest.

## 3.2 Dragon Core System Specifications

| Document | Consumed subject |
|---|---|
| `RCA-DFC-CHTR-002` | Product scope, selected platforms, external-host model, hierarchy, and single-owner rules |
| `RCA-DFC-PBIO-002` | Product and interface responsibility boundaries |
| `RCA-DFC-SRS-002` | Externally observable behavior and host-interface requirements |
| `RCA-DFC-ARCH-002` | Internal architecture and generated-definition ownership |
| `RCA-DFC-REG-002` | Complete host-visible register contract and generated host artifacts |
| `RCA-DFC-VP-002` | Device-verification methods, cases, required outcomes, and evidence |
| `RCA-DFC-RTM-002` | Relationships among controlling technical identifiers |
| `RCA-DFC-RTL-STD-002` | RTL and generated-artifact implementation rules |

## 3.3 Software Specifications

The governing software baseline comprises `RCA-DFC-SW-001` Revision C and `RCA-DFC-SW-002` through `RCA-DFC-SW-005` Revision B. Their normative identifiers shall be consumed by reference and shall not be redefined here.

## 3.4 Hardware Specifications

An approved FPGA integration baseline or future ASIC Integration Specification may be an identified package input. Its presence does not transfer hardware construction, acceptance, or physical-integration ownership to this specification.

## 3.5 External Standards

Applicable language, coding, safety, security, license, records, and assurance standards shall be selected in controlled project profiles. Each release shall record the exact edition or profile used; an unversioned reference shall not establish release compliance.

## 3.6 Document Precedence

`SWBR-REF-001` — Subject ownership shall be determined only by `RCA-DFC-CHTR-002`, Section 3.1, not by document number, file order, or release date.

`SWBR-REF-002` — Historical Revision A content is rationale only and shall not restore superseded processor, firmware, MMIO, memory-map, Caravel, or on-device software assumptions.

`SWBR-REF-003` — A release shall identify every normative source revision it consumes and shall fail if an expected source identity is missing, ambiguous, or inconsistent.

## Table 3-1. Applicable Baseline Classes

| Class | Release use |
|---|---|
| Controlling technical set | Defines the Dragon Core device contract and technical ownership. |
| Governing software set | Defines external-host software architecture, implementation, APIs, coding, and V&V. |
| Platform integration baseline | Identifies the external host and associated FPGA or ASIC configuration. |
| External standards profile | Fixes the editions and assurance rules claimed by the release. |

# 4. Build Configuration Item Identification

## 4.1 Purpose

A Build Configuration Item (BCI) is any controlled input, tool, output, record, or environment definition whose identity can affect a build, verification result, package, deployment, or conformity claim.

## 4.2 Build Configuration Item Definition

BCIs include specifications, machine-readable device-contract sources, source code, generated source, generators, tests, models, dependencies, compilers, linkers, build systems, environment images, scripts, options, keys or signing-service references, packages, manifests, documentation, evidence, defects, deviations, and approvals.

## 4.3 Build Configuration Item Composition

Each BCI record shall contain a stable name, revision or immutable digest, owner, type, approved source, applicable profile, dependency relationships, license or handling classification where applicable, and status.

## 4.4 Configuration Boundaries

Source, generated, build-output, verification-evidence, release, deployment, and archive baselines shall remain separately identifiable. Promotion shall copy or reference immutable content; it shall not silently mutate a prior baseline.

## 4.5 Identification and Version Control

`SWBR-BCI-001` — Every BCI consumed by a release build shall be uniquely identified and retrievable.

`SWBR-BCI-002` — Generated artifacts shall identify their normative source digest and generator digest or version.

`SWBR-BCI-003` — The Dragon Core `DFC_BUILD_ID.BUILD_ID` value defined by `REG-000C` shall remain a hardware implementation identity and shall not substitute for a software component version or software release identity.

## 4.6 Traceability Requirements

Every released artifact shall trace to its direct inputs, producing command or build step, environment, verification evidence, package, and approval record.

## 4.7 Configuration Management Requirements

BCI changes shall use authorized review, impact analysis, status accounting, and baseline promotion. Mutable labels shall not be the sole reference to a released input.

## 4.8 Verification Requirements

`SWBR-BCI-004` — A configuration audit shall prove that the release manifest, actual package contents, evidence, source identities, and approvals describe the same configuration.

## Table 4-1. Build Configuration Item Summary

| BCI class | Minimum identity |
|---|---|
| Source/specification | Repository revision and content digest |
| Generator/generated output | Source digest, generator digest, and output digest |
| Tool/environment | Name, version, configuration, and environment digest |
| Dependency | Name, version, source, integrity, license, and approval |
| Build artifact | Component, profile, target, version, build ID, and digest |
| Evidence | Case, configuration, environment, outcome, and immutable location |
| Release | Release ID, manifest digest, approvals, and package digests |

# 5. Build and Release Philosophy

## 5.1 Purpose

The build-and-release process shall favor explicit inputs, small trusted transformations, deterministic results, automated checks, independent review, and recoverable baselines.

## 5.2 Guiding Principles

`SWBR-PHIL-001` — A release shall be built from an immutable source revision in a clean controlled environment.

`SWBR-PHIL-002` — Generated device-facing artifacts shall be regenerated and checked, never accepted because a checked-in copy appears plausible.

`SWBR-PHIL-003` — Production capability shall be the minimum capability required for approved operation.

## 5.3 Deterministic Builds

Build results shall not depend on wall-clock time, locale, timezone, filesystem enumeration, network availability, unrecorded environment variables, developer home-directory state, or unspecified tool defaults.

## 5.4 Automation First

Repeatable generation, analysis, test, packaging, manifest creation, integrity checks, and audits shall be automated. Manual approval decisions remain recorded human decisions.

## 5.5 Configuration Control

Promotion shall occur only between identified baselines with complete status accounting.

## 5.6 Quality Integration

Build success is necessary but not sufficient. Required software V&V, applicable Verification Plan evidence, review, audit, security, license, and documentation gates shall pass before approval.

## 5.7 Security and Integrity

Release production shall use least privilege, controlled credentials, isolated signing, pinned dependencies, and immutable records.

## 5.8 Continuous Improvement

Process improvements shall be introduced through controlled changes and regression. A process change shall not alter already approved release evidence retroactively.

## 5.9 Compliance Requirements

`SWBR-PHIL-004` — A waiver shall remain visible, bounded, risk-assessed, approved, and excluded from any claim it does not satisfy.

## Table 5-1. Build and Release Principles

| Principle | Required application |
|---|---|
| Determinism | Normalize or control every output-affecting input. |
| Automation | Make the approved path repeatable and reviewable. |
| Least authority | Keep technical facts with their normative owners. |
| Defense in depth | Combine provenance, digests, access control, review, and signatures. |
| Evidence preservation | Retain raw results with processed summaries. |
| Reversibility | Preserve a tested path to the prior approved release. |

# 6. Software Lifecycle Overview

## 6.1 Purpose

The lifecycle defines the controlled progression from approved change through build, verification, release, deployment, maintenance, and retirement.

## 6.2 Lifecycle Model

The lifecycle uses baselined inputs and explicit gates. Activities may iterate, but no artifact may bypass the gates applicable to the release claim.

## 6.3 Development Phase

Changes are implemented on controlled branches, generated artifacts are refreshed, local and continuous checks run, and review findings are resolved.

## 6.4 Build Phase

A clean environment resolves pinned inputs, generates derived content, compiles and links selected profiles, records diagnostics, and emits provisional artifacts and a build manifest.

## 6.5 Verification Phase

Software V&V executes under `RCA-DFC-SW-005`; device and host-boundary evidence is consumed from or contributed to `RCA-DFC-VP-002` without redefining its cases.

## 6.6 Release Phase

Qualified artifacts are packaged, audited, signed, approved, archived, and promoted to an immutable distribution location.

## 6.7 Maintenance Phase

Defects, vulnerabilities, compatibility changes, dependency changes, and support requests enter the same controlled change and regression process.

## 6.8 End-of-Life and Archival

Retirement records shall identify the last supported release, migration or replacement guidance, retained reproduction baseline, residual obligations, and disposition authority.

## 6.9 Compliance Requirements

`SWBR-LIFE-001` — Each release shall record the lifecycle gate at which every included artifact and item of evidence was accepted.

`SWBR-LIFE-002` — Emergency changes shall complete retrospective review, impact analysis, regression, trace update, audit, and approval before general distribution.

## Table 6-1. Software Lifecycle Phases

| Phase | Primary controlled output |
|---|---|
| Development | Reviewed change set |
| Build | Identified provisional artifacts and logs |
| Verification | Reviewed results and dispositions |
| Release | Approved immutable package |
| Deployment | Installation and acceptance record |
| Maintenance | Corrected or superseding baseline |
| Retirement | Archived final baseline and transition record |

# 7. Software Configuration Management Overview

## 7.1 Purpose

Software configuration management preserves identity, authorization, status, reproducibility, and auditability throughout the lifecycle.

## 7.2 Configuration Management Objectives

Objectives are complete BCI identification, controlled change, baseline integrity, status accounting, reproducible retrieval, and independent audit.

## 7.3 Configuration Items

All items listed in Section 4 are configuration managed when they affect a release, evidence, deployment, or maintenance claim.

## 7.4 Baseline Management

Development, verification, release-candidate, approved-release, deployed, and archived baselines shall use immutable identifiers and explicit promotion records.

## 7.5 Change Control

`SWBR-CM-001` — A change request shall identify cause, scope, owners, requirements, interfaces, generated artifacts, source, tests, tools, dependencies, documentation, compatibility, security, regression, released configurations, and approval route.

## 7.6 Status Accounting

Status accounting shall show the current and historical state of changes, defects, deviations, builds, verification, releases, deployments, and archives.

## 7.7 Configuration Audits

Functional and physical configuration audits shall be completed as required by Section 45.

## 7.8 Repository Integrity

`SWBR-CM-002` — Release tags and approved manifests shall be protected from force movement or in-place replacement.

`SWBR-CM-003` — Corrections to approved evidence or metadata shall create a new identified version with an audit trail.

## 7.9 Compliance Requirements

Access to approve changes, alter baselines, publish releases, sign packages, and disposition deviations shall be role controlled and auditable.

## Table 7-1. Software Configuration Management Functions

| Function | Required result |
|---|---|
| Identification | Every controlled item is uniquely named and retrievable. |
| Change control | Every modification is authorized and impact assessed. |
| Status accounting | State and history are visible. |
| Baseline control | Approved content is immutable. |
| Audit | Manifest, content, evidence, and approval agree. |

# 8. Source Code Repository Requirements

## 8.1 Purpose

Repositories provide the controlled source of software, generation inputs, scripts, tests, documentation, and configuration required to reproduce a release.

## 8.2 General Requirements

`SWBR-REPO-001` — Production source shall reside in an access-controlled version-control system with attributable commits and protected release history.

`SWBR-REPO-002` — The repository shall not contain plaintext credentials, private signing keys, unrestricted production-test authorization, or unapproved proprietary material.

## 8.3 Repository Organization

Repository layout shall separate hand-maintained source, generated source, tests, tools, platform adapters, packaging, documentation, and build outputs.

## 8.4 Access Control

Write, review, merge, tag, publish, and administrative permissions shall follow least privilege and separation of duties.

## 8.5 Branch Protection

Protected branches shall require passing required checks, approved review, resolved discussions, current-base integration, and prohibition of direct or force pushes except through a documented recovery procedure.

## 8.6 Repository Integrity

`SWBR-REPO-003` — Submodules, vendored content, large-file objects, and external references shall be pinned to immutable identities and included in availability and integrity checks.

## 8.7 Traceability

Commits and merge records shall reference the approved change, affected requirements, tests, and review.

## 8.8 Documentation

Repository documentation shall identify supported build entry points, prerequisites, generated-content rules, profiles, tests, packaging, and recovery from a clean checkout.

## 8.9 Compliance Requirements

`SWBR-REPO-004` — An obsolete or exploratory file shall not remain in an active production compile, generation, test, or packaging path.

## Table 8-1. Source Code Repository Requirements

| Control | Required condition |
|---|---|
| Commit identity | Attributable and immutable |
| Review | Independent approval for protected content |
| Checks | Required build and V&V gates pass |
| Dependencies | Immutable and integrity checked |
| Secrets | Excluded and scanned |
| Release tags | Protected and manifest linked |

# 9. Repository Organization

## 9.1 Purpose

Repository organization shall make ownership, generated boundaries, build inputs, and production content evident to reviewers and automation.

## 9.2 Organizational Principles

One active source path shall exist for each component and profile. Platform-specific code shall remain behind the HAL/BSP boundaries defined by `RCA-DFC-SW-003`.

## 9.3 Top-Level Repository Structure

| Directory class | Permitted content |
|---|---|
| `spec/` | Controlled software specifications and machine-readable software requirements where stored with code |
| `src/` | Portable production implementation |
| `platform/` | External-host HAL/BSP and platform adapters |
| `include/` | Public hand-maintained interfaces |
| `generated/` | Tool-generated bindings and derived sources |
| `tools/` | Generators, analyzers, and controlled utilities |
| `tests/` | Unit, integration, conformance, and fixture software |
| `build/` | Build definitions, profiles, and environment declarations |
| `package/` | Package layouts, installers, metadata, and release scripts |
| `docs/` | User, API, integration, deployment, and maintenance documentation |

## 9.4 Module Organization

Each component shall have a single owner, public boundary where applicable, private implementation, tests, and build definition.

## 9.5 Shared Components

Shared code shall have an explicit API, dependency direction, version policy, and consuming test coverage. Copy-and-diverge reuse is prohibited for device-facing definitions.

## 9.6 Documentation Organization

Documentation sources shall be versioned with the release they describe and generated outputs shall identify their source and tool.

## 9.7 Build Artifact Organization

Build outputs shall reside outside hand-maintained source directories and shall be disposable and regenerable.

## 9.8 Repository Naming and Ownership

`SWBR-ORG-001` — Names shall identify component, profile, target, and purpose without encoding mutable lifecycle status as technical meaning.

## 9.9 Compliance Requirements

`SWBR-ORG-002` — Repository layout changes shall update build, packaging, documentation, trace, and archive rules in the same controlled change.

## Table 9-1. Repository Organization Controls

| Subject | Rule |
|---|---|
| Generated files | Isolated, reproducible, and not hand edited |
| Platform code | Isolated behind approved interfaces |
| Outputs | Outside production source |
| Tests | Excluded from production link unless explicitly approved |
| Alternate implementations | Exactly one active selection per profile |

# 10. Branching Strategy

## 10.1 Purpose

The branching strategy supports review, stable integration, controlled release preparation, and urgent correction without maintaining multiple ambiguous sources of truth.

## 10.2 Branching Objectives

`SWBR-BRANCH-001` — The protected primary branch shall represent the current integrated development baseline and shall remain buildable under required checks.

## 10.3 Primary Branches

One protected primary branch is required. A separately maintained long-lived development branch may be used only if its purpose, synchronization rules, and promotion gate are documented.

## 10.4 Feature Branches

Change branches shall be short lived, derived from an identified base, associated with an approved change, and removed or archived after merge.

## 10.5 Release Branches

Release branches may stabilize a defined release scope. Only approved corrections, metadata, documentation, and release preparation changes may enter after the release-candidate baseline is declared.

## 10.6 Hotfix Branches

Hotfix branches shall derive from the affected approved release tag, contain only the bounded correction and required supporting changes, and merge forward after approval.

## 10.7 Merge Requirements

Merges to protected branches shall require review, required gates, traceable change authorization, resolved conflicts, and no stale generated artifacts.

## 10.8 Branch Naming Conventions

Names shall include the change or release identifier and a concise purpose. Names shall not contain credentials, personal data, or uncontrolled customer data.

## 10.9 Compliance Requirements

`SWBR-BRANCH-002` — Release artifacts shall be created from an immutable release tag or exact commit, never from an unrecorded working tree or moving branch name.

## Table 10-1. Branch Types

| Type | Permitted purpose |
|---|---|
| Primary | Integrated reviewed baseline |
| Change | Bounded implementation and review |
| Release | Stabilization of an identified candidate |
| Hotfix | Bounded correction of an approved release |

# 11. Version Numbering Policy

## 11.1 Purpose

Version numbers communicate software interface and behavior evolution while remaining distinct from hardware product and register-contract identities.

## 11.2 General Requirements

`SWBR-VER-001` — Every released software component shall have an explicit version and compatibility declaration.

## 11.3 Version Format

Released software components shall use `MAJOR.MINOR.PATCH`. Prerelease labels and build metadata may be appended in a machine-readable form that does not change the three-part compatibility meaning.

## 11.4 Version Assignment

- increment MAJOR for an approved incompatible public API, persistent-schema, or application-protocol change;
- increment MINOR for an approved backward-compatible capability addition; and
- increment PATCH for a backward-compatible correction or internal improvement.

## 11.5 Source Code Identification

The exact repository revision and content digest shall accompany the semantic version. A version string alone is insufficient to identify source.

## 11.6 Build Metadata

Build metadata shall identify the producing pipeline execution, target profile, toolchain/environment, and manifest. It shall not be used as a hidden compatibility decision.

## 11.7 Compatibility Policy

Software version, public API version, persistent-schema version, application-protocol version, Dragon Core product revision, `DFC_REGMAP_REV`, device `DFC_BUILD_ID`, capability bitmap, BSP version, and package version are independent axes.

## 11.8 Documentation Requirements

Documentation shall state which axes it covers and the supported compatibility range.

## 11.9 Compliance Requirements

`SWBR-VER-002` — A release shall not infer register compatibility from software version or filename similarity; it shall use validated product revision, register-map revision, capability, and manifest data as defined by the governing software specifications.

## Table 11-1. Version Number Components

| Component | Meaning |
|---|---|
| MAJOR | Incompatible software contract change |
| MINOR | Backward-compatible capability addition |
| PATCH | Backward-compatible correction |
| Prerelease | Candidate maturity; not an approved production release |
| Build metadata | Exact build instance and provenance |

# 12. Release Identification

## 12.1 Purpose

A release identifier binds an approved scope, component set, manifest, evidence set, and approval record.

## 12.2 General Requirements

`SWBR-RELID-001` — Every release identifier shall be unique and shall resolve to one immutable manifest.

## 12.3 Release Identifier Format

The canonical form is `DFC-SW-<release-family>-<version>-<release-class>-<sequence>`, using controlled lowercase or uppercase conventions consistently. The manifest remains the authoritative expansion of the identifier.

## 12.4 Release Classification

Permitted classes are development, integration, engineering, release-candidate, production, maintenance, and hotfix. Only production, maintenance, and hotfix releases may be represented as approved operational software releases.

## 12.5 Release Metadata

Metadata shall include release ID, class, creation time in UTC, components, profiles, targets, compatibility, source and build identities, verification status, known limitations, approvals, distribution status, and supersession relationships.

## 12.6 Release Manifest

The manifest defined in Section 35 is the authoritative machine-readable release inventory.

## 12.7 Traceability

Each release shall trace to approved changes, requirements, source, generated content, dependencies, build records, evidence, anomalies, deviations, documentation, and approvals.

## 12.8 Documentation Requirements

The release identifier shall appear in release notes, manifests, package metadata, archive inventory, deployment records, and rollback records.

## 12.9 Compliance Requirements

`SWBR-RELID-002` — Reuse of an approved release identifier for different content is prohibited.

## Table 12-1. Release Identification Elements

| Element | Purpose |
|---|---|
| Family | Defines the coordinated product or component set |
| Version | Communicates software compatibility change |
| Class | Defines permitted use and approval level |
| Sequence | Distinguishes candidates or rebuilds |
| Manifest digest | Binds exact released content |

# 13. Development Build Process

## 13.1 Purpose

Development builds provide rapid, repeatable feedback without implying release approval.

## 13.2 General Requirements

Development builds may use developer or continuous-integration environments but shall identify all inputs and shall not bypass device-contract generation or production-capability isolation checks.

## 13.3 Build Inputs

Inputs include an identified source revision, generated-source inputs, pinned dependencies, selected profile, toolchain/environment, options, and test selection.

## 13.4 Build Execution

The build shall validate inputs, regenerate derived artifacts, compare controlled generated outputs, compile, link where applicable, run fast static checks and unit tests, and emit structured results.

## 13.5 Build Outputs

Outputs may include unapproved executables, libraries, test binaries, generated files, logs, reports, and a provisional manifest. They shall be clearly marked nonrelease.

## 13.6 Build Validation

`SWBR-DEV-001` — A development build shall fail on generation error, compile error, unresolved required warning, failed required test, or manifest inconsistency.

## 13.7 Build Records

Records shall include source, environment, commands, options, dependencies, diagnostics, tests, results, artifacts, and digests.

## 13.8 Failure Handling

Failures shall not be hidden by automatic success conversion, log filtering, or reuse of an earlier passing artifact.

## 13.9 Compliance Requirements

`SWBR-DEV-002` — A development artifact shall not be promoted by renaming alone; it shall pass the integration and release processes applicable to its claimed class.

## Table 13-1. Development Build Requirements

| Stage | Required result |
|---|---|
| Resolve | All inputs identified and available |
| Generate | Derived content current and consistent |
| Compile/link | No unresolved errors |
| Check/test | Required fast gates complete |
| Record | Provisional manifest and logs complete |

# 14. Integration Build Process

## 14.1 Purpose

Integration builds combine compatible software components, generated bindings, platform adapters, configurations, and test assets for cross-component verification.

## 14.2 General Requirements

`SWBR-INTG-001` — An integration build shall use only component versions and generated bindings declared compatible by the software architecture and API specifications.

## 14.3 Build Inputs

Inputs shall include an immutable integration baseline, selected target profile, exact BSP/HAL, generated host definitions, dependency inventory, configuration schema, and integration test plan.

## 14.4 Build Execution

Execution shall perform the development checks plus cross-component ABI checks, public-header checks, configuration-schema checks, service/application linking, integration tests, and package-layout validation.

## 14.5 Build Outputs

Outputs shall include integrated executables or libraries, test results, compatibility data, provisional packages, manifest, and applicable platform evidence references.

## 14.6 Integration Validation

Integration validation shall cover startup, compatibility discovery, configuration, active readback, interrupt/event service, diagnostics, persistence, response-loss reconciliation, reset recovery, and configuration reapplication as applicable.

## 14.7 Build Records

The record shall preserve component and platform identities, interface versions, target configuration, hardware/model identity, tests, results, and anomalies.

## 14.8 Failure Handling

An integration failure shall block release promotion of the affected configuration. Component substitution after verification requires impact analysis and rerun of affected evidence.

## 14.9 Compliance Requirements

`SWBR-INTG-002` — FPGA and production-host integration differences shall remain in approved BSP/HAL artifacts and shall not create divergent portable driver semantics.

## Table 14-1. Integration Build Requirements

| Integration subject | Required evidence |
|---|---|
| Generated contract | Source and output consistency |
| Component ABI/API | Compatible declarations and link results |
| Platform adapter | Approved BSP/HAL identity and conformance |
| Workflow behavior | Passing integration and recovery scenarios |
| Package | Complete provisional inventory and manifest |

# 15. Release Build Process

## 15.1 Purpose

Release builds produce candidate artifacts eligible for formal approval and distribution.

## 15.2 General Requirements

`SWBR-REL-001` — A release build shall run in a clean, controlled, access-restricted environment from an immutable source tag or commit.

`SWBR-REL-002` — A release build shall perform no implicit network retrieval and shall use only approved pinned inputs whose integrity is verified before use.

## 15.3 Release Build Inputs

Inputs shall include approved source, governing specification identities, generated-contract sources, generator, toolchain/environment, dependencies, profile, target, configuration, verification plan or execution selection, packaging rules, and release metadata.

## 15.4 Release Build Execution

Execution shall perform input validation, generation, consistency checks, compilation/link, static analysis, required tests, reproducibility comparison, package construction, manifest generation, SBOM generation, checksum generation, audit, and signing preparation.

## 15.5 Release Artifacts

Artifacts shall include applicable external-host executables, libraries, BSP/HAL components, generated definitions, configuration schemas, tools, documentation, manifests, SBOM, notices, digests, verification summaries, and compatibility data.

## 15.6 Release Qualification

Qualification shall use Sections 42 through 45 and the exit criteria in Section 51. Signing and publication shall occur only after qualification or shall produce a clearly identified unsigned candidate not available as an approved release.

## 15.7 Build Records

Release records shall be immutable, complete, time-stamped in UTC, and associated with the manifest digest.

## 15.8 Failure Handling

`SWBR-REL-003` — A failed release build shall not reuse partial outputs in a later release attempt unless each reused item is content-addressed, independently verified, and permitted by the controlled build design.

## 15.9 Compliance Requirements

No manual edit is permitted between qualified build output and signed release content. Any change requires a new build and affected verification.

## Table 15-1. Release Build Requirements

| Requirement | Release condition |
|---|---|
| Clean baseline | Exact immutable source and inputs |
| Controlled execution | Approved environment and no implicit retrieval |
| Complete checks | All applicable gates executed |
| Reproducibility | Required comparison passed |
| Package integrity | Inventory, manifest, digests, and content agree |
| Approval readiness | Evidence, audit, and documentation complete |

# 16. Build Environment Requirements

## 16.1 Purpose

Build environments shall be defined, reproducible, isolated from unapproved state, and sufficient for independent reconstruction.

## 16.2 General Requirements

`SWBR-ENV-001` — The environment shall identify operating system or runtime image, architecture, tool versions, locale, timezone, environment variables, filesystem assumptions, network policy, and resource limits.

## 16.3 Approved Build Platforms

Approved platforms are project-controlled host environments capable of executing the selected toolchain. Container or virtual-machine images may provide the canonical environment when their base, content, and digest are controlled.

## 16.4 Toolchain Requirements

Only approved versions and configurations shall be used for release. Tool substitutions require impact analysis and applicable regression.

## 16.5 Environment Configuration

Release builds shall set locale and timezone explicitly, use clean work and output directories, restrict environment inheritance, fix path-sensitive options where practical, and prevent access to developer-specific files.

## 16.6 Environment Validation

The environment shall pass self-tests that confirm tool identity, expected configuration, generated-contract availability, dependency integrity, clock handling, filesystem behavior, and output isolation.

## 16.7 Security Requirements

Release workers shall use ephemeral or restored-clean environments, least-privilege service identities, controlled secrets injection, outbound-network restrictions, and tamper-evident logs.

## 16.8 Environment Maintenance

Updates shall be reviewed for correctness, security, reproducibility, compatibility, and regression impact. Prior environment images needed for supported releases shall remain retrievable.

## 16.9 Compliance Requirements

`SWBR-ENV-002` — A release record shall contain the immutable environment identity; a human-readable tool list alone is insufficient.

## Table 16-1. Build Environment Requirements

| Environment element | Required control |
|---|---|
| Runtime image | Immutable digest |
| Tools | Exact version and configuration |
| Locale/time | Explicit and normalized |
| Network | Denied or explicitly approved per step |
| Credentials | Ephemeral, scoped, and excluded from outputs |
| Workspace | Clean input and isolated output |

# 17. Supported Development Platforms

## 17.1 Purpose

Supported development platforms are external computing environments. None is a processor or software environment inside Dragon Core.

## 17.2 General Requirements

`SWBR-PLAT-001` — Each supported platform shall have an approved profile stating processor architecture, operating system or RTOS/bare-metal environment, ABI, compiler, BSP/HAL, storage, timing, interrupt, and SPI-controller assumptions.

## 17.3 Host Development Platforms

Hosted development platforms may build and test portable components and tools. Their support status shall be declared separately from deployable target support.

## 17.4 Target Development Platforms

The VisionFive 2 is the selected primary external FPGA-validation host under `RCA-DFC-CHTR-002`, Section 5.2. Production external-host platforms shall be identified by their approved platform profiles; this specification does not invent a production host selection.

## 17.5 Virtualization and Container Support

Virtualization may be used for builds and host-only tests when its effect on timing, devices, file systems, and evidence is understood. Hardware timing and interrupt claims shall use an environment permitted by the applicable verification specification.

## 17.6 Platform Qualification

Platform support requires successful compiler, ABI, BSP/HAL conformance, integration, resource, timing, recovery, packaging, and deployment evidence for the claimed scope.

## 17.7 Platform Maintenance

Platform updates shall trigger impact analysis across BSP/HAL behavior, compiler, libraries, kernel/RTOS, SPI controller, interrupt handling, packaging, deployment, and verification.

## 17.8 Platform Documentation

Documentation shall identify prerequisites, build and installation steps, permissions, device connection, limitations, timing assumptions, and recovery.

## 17.9 Compliance Requirements

`SWBR-PLAT-002` — FPGA validation software shall not rely on a VisionFive 2 or ECP5 private path that is absent from the documented production SPI/register contract.

## Table 17-1. Supported Development Platforms

| Platform class | Required designation |
|---|---|
| Hosted build platform | Development and automation only unless separately qualified |
| VisionFive 2 | Primary external ECP5 validation host |
| Production external host | Selected by an approved platform profile |
| HIL/post-silicon host | Identified by exact host, BSP/HAL, and fixture configuration |

# 18. Compiler Toolchain Requirements

## 18.1 Purpose

Compiler toolchains transform external-host source into software artifacts and shall be controlled as BCIs.

## 18.2 General Requirements

`SWBR-TOOL-001` — Each toolchain shall identify compiler, assembler where used, linker, archiver, binary utilities, runtime libraries, code generator, static-analysis tools, and their configurations.

## 18.3 Supported Toolchains

Supported toolchains shall implement the C17 and permitted C++ boundaries defined by `RCA-DFC-SW-002` through `RCA-DFC-SW-004` for the selected external-host profile.

## 18.4 Compiler Configuration

Compile options shall explicitly define language mode, ABI, warnings, optimization, debug information, hardening, instrumentation, feature selection, include paths, and generated-definition identity.

## 18.5 Linker and Binary Utilities

Linker and binary utilities apply only to external-host artifacts. They shall not presume a Dragon Core processor address space, boot vector, ROM, RAM, flash, exception table, or executable memory.

## 18.6 Toolchain Validation

Validation shall include known-answer builds, diagnostic-policy checks, ABI/header compatibility, optimization-sensitive tests, generated-source compilation, and artifact inspection.

## 18.7 Toolchain Maintenance

A version change shall be treated as a build-input change and shall rerun the regression selected by impact analysis.

## 18.8 Documentation

Toolchain records shall identify source, license, version, configuration, known limitations, approved deviations, and environment identity.

## 18.9 Compliance Requirements

`SWBR-TOOL-002` — Tool qualification, certification credit, or reduced verification credit shall not be claimed unless established by a separate approved assurance plan.

## Table 18-1. Compiler Toolchain Requirements

| Toolchain subject | Required evidence |
|---|---|
| Version/configuration | Immutable environment and command record |
| Diagnostics | Reviewed warning and analysis policy |
| ABI | Header, calling convention, and link checks |
| Optimization | Required tests at release settings |
| Runtime | Exact library and license inventory |

# 19. Linker Configuration

## 19.1 Purpose

Linker configuration governs only executables and libraries for an external host.

## 19.2 General Requirements

`SWBR-LINK-001` — Every link shall identify its target processor, ABI, runtime model, entry point, library order, memory regions where applicable, and output format.

## 19.3 Linker Scripts

External embedded-host linker scripts shall be version controlled, profile specific, reviewed, and tested. Hosted platforms may use a controlled default linker specification when its identity and effect are recorded.

## 19.4 Memory Layout

Memory maps, stack, heap, interrupt vectors, startup sections, and persistent regions belong to the external-host platform profile. No such object shall be described as a Dragon Core internal memory map.

## 19.5 Linker Options

Options shall control section placement, dead-code removal, symbol visibility, map generation, hardening, reproducibility, and diagnostic behavior as applicable.

## 19.6 Binary Generation

Binary conversion shall preserve the external-host target format and shall not create an image intended for programming into Dragon Core.

## 19.7 Validation

Link validation shall inspect unresolved symbols, duplicate definitions, entry point, section bounds, stack/heap budget, prohibited objects, engineering-feature exclusion, and map consistency.

## 19.8 Documentation

The release package shall identify the linker configuration, memory assumptions, map digest, binary format, loader or installer, and platform owner.

## 19.9 Compliance Requirements

`SWBR-LINK-002` — The terms firmware image and binary image in this specification shall always mean an external-host image.

## Table 19-1. Linker Configuration Requirements

| Link item | Required control |
|---|---|
| Script/specification | Versioned and target-profile bound |
| External-host memory | Defined by platform owner |
| Map file | Generated and reviewed |
| Prohibited content | Test backdoors, unintended libraries, duplicate generated definitions |
| Output | External-host format only |

# 20. Build System Architecture

## 20.1 Purpose

The build system shall implement one explicit directed build graph from controlled inputs to independently identifiable outputs.

## 20.2 General Requirements

`SWBR-SYS-001` — Build steps shall declare their inputs, outputs, tools, options, environment, and failure conditions.

## 20.3 Architectural Principles

The build shall separate source resolution, device-contract generation, compilation, linking, analysis, test, packaging, integrity, signing, publication, and archive steps.

## 20.4 Core Components

Core components are the orchestrator, environment resolver, generator runner, compiler/linker adapter, analysis/test runner, package builder, manifest/SBOM generator, integrity checker, release auditor, signing interface, publisher, and archive interface.

## 20.5 Build Pipeline

The pipeline shall stop on an unmet prerequisite and shall not execute publication or signing after an upstream failure.

## 20.6 Automation Interfaces

Automation shall provide stable noninteractive entry points, structured results, deterministic exit codes, log locations, and artifact inventories.

## 20.7 Scalability and Maintainability

Reusable build rules shall preserve component ownership and shall not hide profile-specific sources, options, or capabilities.

## 20.8 Documentation

The build graph, profile selection, generation flow, failure semantics, clean-build procedure, and local/CI equivalence shall be documented.

## 20.9 Compliance Requirements

`SWBR-SYS-002` — A build cache shall never determine correctness; cache hits shall be content-addressed and the uncached build shall remain supported and periodically verified.

## Table 20-1. Build System Architecture Components

| Component | Required responsibility |
|---|---|
| Resolver | Select exact controlled inputs |
| Generator | Produce owner-derived definitions |
| Builder | Compile/link selected profiles |
| Verifier | Run analyses and tests |
| Packager | Construct declared release layout |
| Recorder | Produce manifest, SBOM, logs, and digests |
| Publisher | Promote only approved immutable content |

# 21. Build Configuration Profiles

## 21.1 Purpose

Profiles define intentional build variations without permitting undocumented conditional behavior.

## 21.2 General Requirements

`SWBR-PROF-001` — Every profile shall define included components, feature flags, optimization, diagnostics, instrumentation, target, BSP/HAL, packaging, tests, and permitted use.

## 21.3 Supported Profiles

| Profile | Permitted content and use |
|---|---|
| Development | Debug information and developer diagnostics; no release claim |
| Test | Instrumentation, test doubles, sanitizers, or coverage; no operational deployment |
| Engineering | Explicitly authorized raw access, fault injection, or bring-up capability; controlled distribution only |
| Production | Minimum approved operational capability; no test backdoors or unrestricted raw engineering access |

## 21.4 Profile Configuration

Profile definitions shall be reviewed source, not unrecorded command-line conventions.

## 21.5 Profile Selection

The selected profile shall be explicit in the build command, artifact name, manifest, embedded software version information where supported, package metadata, and evidence.

## 21.6 Profile Validation

Validation shall prove required capabilities are present and prohibited capabilities absent. Production exclusion shall use source/link inventory and behavioral or structural checks, not naming alone.

## 21.7 Change Management

Profile changes require impact analysis across source selection, APIs, security, verification, packaging, compatibility, and deployment.

## 21.8 Documentation

Documentation shall state permitted use, limitations, distribution controls, and compatibility for each profile.

## 21.9 Compliance Requirements

`SWBR-PROF-002` — Engineering and production artifacts shall be noninterchangeable and shall have distinct identities and package channels.

## Table 21-1. Standard Build Configuration Profiles

| Profile | Release approval | Operational use |
|---|---|---|
| Development | No | No |
| Test | No | No |
| Engineering | Bounded engineering approval | Laboratory/bring-up only |
| Production | Full release approval | Approved external-host use |

# 22. Dependency Management

## 22.1 Purpose

Dependency management ensures that every direct and transitive dependency is known, reproducible, legally usable, secure enough for its role, and available for long-term support.

## 22.2 General Requirements

`SWBR-DEP-001` — Dependencies shall be pinned to immutable versions or content digests and resolved from approved sources.

## 22.3 Dependency Identification

Each dependency shall record name, version, source, digest, direct consumers, transitive dependencies, license, build options, patches, support status, and approval.

## 22.4 Dependency Classification

Dependencies shall be classified as production runtime, build-time, test-only, documentation, tool, platform, or optional. Test-only dependencies shall not enter production packages.

## 22.5 Version Control

Lockfiles, vendored sources, patches, mirrors, and package indexes used by a release shall be versioned or immutably identified.

## 22.6 Dependency Validation

Validation shall include integrity, license, provenance, API/ABI compatibility, known-vulnerability review, build reproducibility, and tests appropriate to criticality.

## 22.7 Dependency Change Management

Updates shall identify motivation, affected interfaces and components, security and license changes, regression scope, compatibility, and rollback.

## 22.8 Documentation

The release shall include a machine-readable software bill of materials (SBOM) and required attribution or license notices.

## 22.9 Compliance Requirements

`SWBR-DEP-002` — An unapproved, floating, unavailable, unverifiable, or license-incompatible dependency shall fail the release gate.

`SWBR-DEP-003` — Release reproduction shall not depend on a public service remaining available; approved source or package copies shall be retained or mirrored according to policy.

## Table 22-1. Dependency Management Requirements

| Attribute | Required value |
|---|---|
| Identity | Name, version, source, and digest |
| Role | Runtime, build, test, tool, or documentation |
| Legality | License and notice disposition |
| Security | Review status and known residual findings |
| Availability | Retained source/package and build instructions |

# 23. Third-Party Software Management

## 23.1 Purpose

Third-party software shall be evaluated and controlled throughout acquisition, integration, maintenance, release, and retirement.

## 23.2 General Requirements

`SWBR-TPS-001` — Third-party code shall not be accepted solely because it is common, open source, vendor supplied, or already present on a developer system.

## 23.3 Identification and Inventory

The inventory shall include upstream project/vendor, version, source location, digest, maintainer status, license, known modifications, consumers, criticality, and replacement strategy.

## 23.4 Evaluation and Approval

Evaluation shall address functionality, quality, security, support, provenance, license, export or contractual constraints, build reproducibility, testability, and lifecycle risk.

## 23.5 Licensing Requirements

License obligations shall be reviewed before integration and fulfilled in source, binary, documentation, notice, offer, and distribution forms as applicable.

## 23.6 Security and Vulnerability Management

Known vulnerabilities shall be assessed for applicability, exploitability, operational exposure, mitigation, correction, and release impact. Absence of a public advisory is not proof of fitness.

## 23.7 Update and Change Control

Local patches shall be separately versioned, documented, reviewed, and tested. Unmaintained critical dependencies require an approved containment, fork, replacement, or retirement plan.

## 23.8 Documentation

Third-party notices, source obligations, modifications, configuration, and residual risks shall accompany the release or its controlled distribution record.

## 23.9 Compliance Requirements

`SWBR-TPS-002` — A release shall fail when a third-party obligation, material security finding, provenance gap, or unavailable required source remains unresolved.

## Table 23-1. Third-Party Software Management Requirements

| Review area | Required disposition |
|---|---|
| Provenance | Known and verified |
| License | Compatible and fulfilled |
| Security | Assessed and accepted or corrected |
| Maintenance | Supported or mitigated |
| Modifications | Versioned and tested |

# 24. Build Automation

## 24.1 Purpose

Build automation implements the repeatable approved path and produces objective records.

## 24.2 General Requirements

`SWBR-AUTO-001` — Automation shall use noninteractive, version-controlled commands with deterministic exit status and structured result output.

## 24.3 Automation Scope

Automation shall cover input validation, generation, formatting checks, compile/link, static analysis, tests, coverage, package creation, manifest/SBOM generation, reproducibility, integrity checks, audit, and archive preparation.

## 24.4 Automation Framework

The framework shall isolate jobs, declare dependencies, enforce timeouts, capture logs, preserve failed evidence, and avoid hidden global state.

## 24.5 Build Orchestration

Orchestration shall execute only steps applicable to the selected profile and release class while making skipped and not-applicable steps explicit.

## 24.6 Error Handling

Failures, timeouts, cancellations, missing artifacts, malformed results, and infrastructure errors shall be distinct result states. Infrastructure invalidation shall trigger rerun, not pass.

## 24.7 Security

Automation shall use scoped service identities, protected variables, approved workers, verified inputs, secret redaction, and artifact access controls.

## 24.8 Documentation

Each automated job shall identify purpose, inputs, outputs, tool/environment, timeout, retry policy, failure behavior, and retained evidence.

## 24.9 Compliance Requirements

`SWBR-AUTO-002` — Automation shall not automatically retry a state-changing hardware operation whose completion may be ambiguous; applicable tests and bring-up tools shall use reconciliation rules from the governing software specifications.

## Table 24-1. Build Automation Requirements

| Automation property | Requirement |
|---|---|
| Deterministic | Same declared inputs select the same graph and options |
| Observable | Logs, results, artifacts, and skipped steps are explicit |
| Fail closed | Missing or invalid prerequisites block promotion |
| Secure | Secrets and publication authority are isolated |
| Reproducible | Clean local and CI entry points are equivalent in function |

# 25. Continuous Integration Build Pipeline

## 25.1 Purpose

Continuous integration (CI) provides timely, repeatable evidence that proposed changes remain compatible with the controlled baseline.

## 25.2 General Requirements

`SWBR-CI-001` — Every proposed merge to a protected branch shall run the required checks for the affected components and profiles.

## 25.3 Pipeline Architecture

The pipeline shall separate untrusted change validation, trusted integration, release-candidate construction, signing, and publication into permission-isolated stages.

## 25.4 Trigger Conditions

Triggers shall include proposed changes, protected-branch updates, release tags, dependency or environment changes, generator or normative-source changes, scheduled integrity checks, and authorized manual release actions.

## 25.5 Quality Gate Integration

Required gates shall include source hygiene, generation consistency, build, static analysis, tests, coverage, dependency/license/security checks, documentation/reference checks, package audit, and reproducibility according to applicability.

## 25.6 Failure Management

Failed required jobs shall block merge or promotion. Selective rerun shall preserve the original failure and identify the rerun reason and attempt.

## 25.7 Reporting and Notifications

CI shall publish structured status linked to the exact commit, environment, profile, and artifacts. Summary success shall not conceal failed or skipped required jobs.

## 25.8 Security and Access Control

Unreviewed code shall not receive release-signing credentials, production publication authority, or unrestricted access to protected artifacts.

## 25.9 Compliance Requirements

`SWBR-CI-002` — A release shall not rely solely on a merge-time CI run when the release source, environment, dependencies, profile, or options differ from that run.

## Table 25-1. Continuous Integration Pipeline Requirements

| Stage | Trust level | Output |
|---|---|---|
| Change validation | Untrusted | Review feedback only |
| Protected integration | Controlled | Integrated build and test evidence |
| Release candidate | Trusted | Auditable unsigned candidate |
| Approval/signing | Restricted | Approved signed release |
| Publication | Restricted | Immutable distribution record |

# 26. Build Verification

## 26.1 Purpose

Build verification establishes that the build graph executed correctly and produced artifacts that correspond to the declared inputs and profiles.

## 26.2 General Requirements

`SWBR-BV-001` — Build verification shall be distinct from functional software verification; both are required when applicable.

## 26.3 Verification Objectives

Objectives are correct source selection, current generated content, successful compilation/linking, expected artifact inventory, absence of prohibited content, manifest agreement, dependency agreement, and deterministic packaging.

## 26.4 Verification Activities

Activities shall include clean-build checks, generated diff checks, header/API compile checks, symbol and section inspection, dependency closure, package inventory comparison, manifest schema validation, digest verification, profile exclusion checks, and smoke execution where applicable.

## 26.5 Build Integrity

Every artifact shall be tied to its producing build record. Post-build changes shall invalidate the artifact's qualification unless the transformation is an identified packaging/signing step recorded in the manifest.

## 26.6 Verification Records

Records shall identify check, expected rule, inputs, tool, observed result, output, verdict, and reviewer where required.

## 26.7 Failure Handling

Build-verification failure shall block promotion. A packaging or manifest correction requires rerun of affected checks and reproducibility evaluation.

## 26.8 Documentation

Build verification procedures shall state which properties are structural, behavioral, cryptographic, or review based.

## 26.9 Compliance Requirements

`SWBR-BV-002` — A successful tool return code shall not substitute for artifact inspection, manifest comparison, and required tests.

## Table 26-1. Build Verification Requirements

| Verification area | Required result |
|---|---|
| Source selection | Exact approved files and revisions |
| Generated content | Matches owner-derived source and generator |
| Artifact inventory | Expected items only |
| Profile isolation | Required present; prohibited absent |
| Manifest | Schema valid and content accurate |
| Digests | Recompute and match |

# 27. Build Reproducibility Requirements

## 27.1 Purpose

Reproducibility demonstrates that an approved release can be regenerated without dependence on undocumented transient state.

## 27.2 General Requirements

`SWBR-REPRO-001` — Production release artifacts shall be rebuilt at least twice from the same controlled inputs in clean environments and compared according to this section.

## 27.3 Controlled Inputs

Controlled inputs shall include source and specifications, machine-readable definitions, generator, dependencies, environment, toolchain, options, profile, target, configuration, locale, timezone, seeds, packaging rules, and permitted signing inputs.

## 27.4 Deterministic Build Process

The build shall normalize timestamps, archive member order, filesystem traversal, generated identifiers, temporary paths, debug-prefix paths, locale-dependent text, compression settings, and other output-affecting nondeterminism where practical.

## 27.5 Environment Preservation

Environment images, tool packages, sources, dependencies, licenses, commands, and configuration shall be retained for supported releases.

## 27.6 Artifact Verification

Unsigned deterministic artifacts shall match byte for byte. If an approved format contains unavoidable nondeterministic fields, the release shall identify each field, prove semantic equivalence with an independent comparison, and exclude mutable signing timestamps from the unsigned-artifact comparison boundary.

## 27.7 Change Control

Any newly observed nondeterminism is a finding requiring root cause, disposition, regression, and update of the reproducibility comparison.

## 27.8 Documentation

The reproduction procedure shall be executable by an independent authorized party from the archived baseline.

## 27.9 Compliance Requirements

`SWBR-REPRO-002` — A source-only archive without the required environment, dependencies, generation inputs, commands, and package rules does not satisfy reproducibility.

## Table 27-1. Build Reproducibility Requirements

| Comparison object | Acceptance |
|---|---|
| Generated source | Byte-identical |
| External-host binary/library | Byte-identical unless bounded fields are approved |
| Package before signing | Byte-identical |
| Manifest/SBOM | Byte-identical except explicitly excluded signature material |
| Evidence | Same declared configuration and repeatable verdict |

# 28. Firmware Image Generation

## 28.1 Purpose

This section governs external embedded-host firmware images defined by `RCA-DFC-SW-002`. Dragon Core contains no firmware image and provides no firmware programming or boot interface.

## 28.2 General Requirements

`SWBR-FWIMG-001` — Every firmware image shall identify the external-host platform profile, component version, build identity, manifest, and compatible Dragon Core product/register contract.

## 28.3 Input Requirements

Inputs shall include approved external-host firmware source, generated bindings, BSP/HAL, linker configuration, target profile, toolchain, dependencies, configuration defaults or schemas, and release metadata.

## 28.4 Image Generation Process

Generation shall compile and link the external-host image, inspect sections and symbols, verify resource budgets, exclude engineering-only content for production, create the external-host loader format, and bind it to the release manifest.

## 28.5 Supported Image Formats

Formats shall be those required by the approved external-host bootloader, operating system, RTOS, bare-metal loader, or installer. A format name shall not imply support for programming Dragon Core.

## 28.6 Image Validation

Validation shall include format integrity, entry point, section bounds, load/launch procedure, version reporting where supported, generated-binding identity, cold start, reset/reconnect recovery, and rollback.

## 28.7 Image Identification

External-host firmware identity shall remain independent of `DFC_BUILD_ID`, which identifies the Dragon Core hardware implementation.

## 28.8 Documentation

Documentation shall state the external target, loader, prerequisites, installation, verification, recovery, rollback, compatibility, and limitations.

## 28.9 Compliance Requirements

`SWBR-FWIMG-002` — No package, label, or procedure shall state or imply that executable firmware is loaded into or executed by Dragon Core.

## Table 28-1. Firmware Image Generation Requirements

| Subject | Required result |
|---|---|
| Execution location | External host only |
| Device access | SRS-defined SPI and Register-Map-defined contract |
| Target identity | Approved external-host profile |
| Compatibility | Product/revision/register/capability declaration |
| Recovery | Tested reinstall and rollback |

# 29. FPGA Software Package Generation

## 29.1 Purpose

An FPGA software package provides external-host software and evidence needed to operate or validate the ECP5 Dragon Core realization with the VisionFive 2 validation host.

## 29.2 General Requirements

`SWBR-FPGA-001` — The package shall preserve the same documented SPI/register software contract used for production and shall identify every FPGA-only element as validation infrastructure.

## 29.3 Package Inputs

Inputs shall include the approved VisionFive 2 BSP/HAL, portable driver, generated bindings, validation applications, configuration, tests, documentation, and an identified FPGA hardware image and hardware manifest supplied by its owner.

## 29.4 Package Generation Process

The process shall build the validation-host profile, assemble tools and tests, validate package inventory and compatibility, bind hardware and software identities without merging them, and generate integrity metadata.

## 29.5 Package Contents

Contents may include VisionFive 2 executables, libraries, BSP/HAL, typed APIs, conformance client, fixtures/scripts, configuration schemas, generated definitions, hardware-image reference or separately approved image, manifests, evidence references, and instructions.

## 29.6 Package Validation

Validation shall include installation, identity discovery, SPI/interrupt operation, configuration, active readback, diagnostics, event/interrupt service, reconciliation, reset recovery, and absence of undocumented FPGA-private software dependence.

## 29.7 Package Identification

The package shall record software release ID, VisionFive 2 profile, FPGA hardware build identity, wrapper identity, board/fixture identity, and applicable Verification Plan cases.

## 29.8 Documentation

Documentation shall distinguish software defects, FPGA integration defects, board/fixture defects, and Dragon Core device-contract defects by owner.

## 29.9 Compliance Requirements

`SWBR-FPGA-002` — Inclusion of an FPGA bitstream does not make that bitstream software or transfer its construction and acceptance to this specification.

## Table 29-1. FPGA Software Package Generation Requirements

| Package element | Owner/identity rule |
|---|---|
| VisionFive 2 software | Software release manifest |
| Generated host definitions | Register/Architecture source and generator manifest |
| FPGA hardware image | Separate hardware build identity |
| Board/fixture | Separate integration identity |
| Evidence | Applicable VP and software V&V references |

# 30. ASIC Software Package Generation

## 30.1 Purpose

An ASIC software package provides external-host software, tools, and documentation for bring-up, validation, manufacturing support, maintenance, or production use with a fabricated Dragon Core device.

## 30.2 General Requirements

`SWBR-ASIC-001` — The package shall contain no ASIC-local executable, RISC-V BSP, direct MMIO driver, OpenFrame-supplied host interface assumption, or alternate register path.

## 30.3 Package Inputs

Inputs shall include the approved production or bring-up external-host profile, portable driver, generated bindings, selected BSP/HAL, configuration, tools, documentation, tests, and identified fabricated-device/build and board/fixture configurations.

## 30.4 Package Generation Process

The process shall build the selected external-host profile, verify compatibility declarations, assemble only authorized tools, bind separate software/device/platform identities, and generate manifest, SBOM, digests, and release records.

## 30.5 Package Contents

Contents may include external-host executables, libraries, APIs, configuration schemas, manufacturing or diagnostic tools, conformance tests, release notes, compatibility data, deployment/rollback instructions, manifests, and evidence references.

## 30.6 Package Validation

Bring-up and production packages shall validate identity, reset-safe state, host readiness, SPI/register access, protected operations, active readback, representative workflows, interrupts, events, diagnostics, response-loss reconciliation, reset recovery, and configuration reapplication as applicable.

## 30.7 Package Identification

Software release ID, external-host/BSP identity, fabricated-device product revision, register-map revision, `DFC_BUILD_ID`, board/fixture identity, and integration baseline shall be recorded as independent fields.

## 30.8 Documentation

Documentation shall state prerequisites, connection and ownership boundaries, compatible device builds, permitted use, security controls, deployment, validation, rollback, and support.

## 30.9 Compliance Requirements

`SWBR-ASIC-002` — A bring-up exception or engineering tool shall not enter a production package without explicit production authorization, security review, source/link inclusion, verification, and documentation.

## Table 30-1. ASIC Software Package Generation Requirements

| Identity | Meaning |
|---|---|
| Software release | External-host software content |
| BSP/HAL profile | External-host platform integration |
| Device product/register revision | Programming-contract compatibility |
| Device `BUILD_ID` | Hardware implementation identity |
| Board/fixture | External physical integration |

# 31. Binary Packaging Requirements

## 31.1 Purpose

Binary packages distribute external-host executables and related runtime content in a controlled layout.

## 31.2 General Requirements

`SWBR-BIN-001` — A binary package shall contain only declared files whose digests appear in the manifest.

## 31.3 Package Contents

Contents may include executables, runtime libraries, configuration schemas, generated public data, launch/service definitions, notices, documentation, manifest, SBOM, checksums, and signatures.

## 31.4 Package Structure

Paths, permissions, owners, executable bits, symbolic links, case sensitivity, timestamps, compression, and archive order shall be deterministic and validated for the target platform.

## 31.5 Binary Identification

File and package metadata shall identify component version, release ID, target, profile, and manifest digest. Device compatibility shall be represented separately.

## 31.6 Integrity Verification

The package shall be verified after construction and after transfer using Section 37. Signature verification shall use Section 36 when signing applies.

## 31.7 Packaging Validation

Validation shall check expected inventory, duplicate or undeclared files, permissions, dependencies, loader paths, symbols where appropriate, engineering-content exclusion, installation, execution, uninstall, and rollback.

## 31.8 Documentation

Instructions shall state platform, prerequisites, installation, configuration, verification, update, rollback, support, and removal.

## 31.9 Compliance Requirements

`SWBR-BIN-002` — Stripping, compression, signing, or installer wrapping shall be explicit manifest transformations and shall not obscure the identity of the underlying qualified binary.

## Table 31-1. Binary Packaging Requirements

| Check | Required result |
|---|---|
| Inventory | Declared files only |
| Permissions | Least privilege and target appropriate |
| Dependencies | Complete and approved |
| Identity | Version, profile, target, release, manifest |
| Integrity | Digests and signatures verify |

# 32. Library Packaging Requirements

## 32.1 Purpose

Library packages distribute public Dragon SDK, driver, HAL, support, or integration libraries for external hosts.

## 32.2 General Requirements

`SWBR-LIB-001` — Each library package shall declare public API/ABI version, supported language and target profiles, thread/context rules, dependencies, and compatibility.

## 32.3 Supported Library Types

Static libraries, shared libraries, import libraries, source packages, and language bindings may be released when approved for a target profile.

## 32.4 Package Contents

Contents shall include applicable library binaries or source, public headers, generated bindings, package metadata, examples, API documentation, licenses/notices, manifest, SBOM, digests, and tests or test references.

## 32.5 Versioning and Identification

Library filename, soname or equivalent ABI identity, package version, public API version, and manifest shall agree.

## 32.6 Validation

Validation shall compile public headers in supported language modes, link and execute representative consumers, check exported symbols, verify generated-definition identity, and test compatibility and uninstall/upgrade paths.

## 32.7 Distribution Requirements

Development headers and static archives shall be separated from runtime-only packages where the target package system uses that distinction.

## 32.8 Documentation

Documentation shall include initialization, storage, concurrency, deadlines, errors, state-changing side effects, reconciliation, compatibility, and examples required by `RCA-DFC-SW-003`.

## 32.9 Compliance Requirements

`SWBR-LIB-002` — Public packages shall not expose engineering raw-access APIs in a production profile unless separately named, authorized, and controlled.

## Table 32-1. Library Packaging Requirements

| Library subject | Required evidence |
|---|---|
| Public headers | C17 and supported C++ compatibility compile |
| ABI | Exported-symbol and consumer-link checks |
| Generated bindings | Source/generator/output identity |
| Compatibility | Supported product/register/API/profile matrix |
| Examples | Build and run against released package |

# 33. Installation Package Generation

## 33.1 Purpose

Installation packages deploy software to an external host. They do not install software into Dragon Core.

## 33.2 General Requirements

`SWBR-INSTALL-001` — Installation shall be noninteractive or explicitly scripted for controlled deployment, shall validate prerequisites and integrity, and shall fail without leaving an undocumented partial state.

## 33.3 Package Inputs

Inputs shall be qualified binary/library packages, approved configuration schemas and defaults, service definitions, migration tools, documentation, manifest, SBOM, digests, and signatures.

## 33.4 Package Generation Process

Generation shall use deterministic layouts, controlled package metadata, explicit ownership and permissions, pre/post actions with bounded effects, and rollback information.

## 33.5 Package Contents

Contents may include external-host executables and libraries, public data, configurations, services, rules, migration tools, notices, manifest, verification utility, documentation, and uninstall metadata.

## 33.6 Package Validation

Validation shall cover clean install, upgrade from every supported prior version, downgrade or rollback where supported, configuration preservation/migration, failed-install recovery, service start/stop, permissions, removal, and reinstall.

## 33.7 Package Identification

Package manager identity, software release ID, target profile, architecture, package revision, and manifest digest shall be mutually consistent.

## 33.8 Documentation

Installation documentation shall distinguish host software installation from FPGA programming, ASIC manufacturing, and Dragon Core configuration through the SPI/register contract.

## 33.9 Compliance Requirements

`SWBR-INSTALL-002` — An installer shall not automatically enable externally effective Dragon Core operation without the explicit validated configuration and authorization workflow defined by the governing software specifications.

## Table 33-1. Installation Package Generation Requirements

| Scenario | Required result |
|---|---|
| Clean install | Complete and verified |
| Upgrade | Configuration and data migrated as declared |
| Failure | Bounded partial state and recovery |
| Rollback | Prior approved version restored |
| Removal | Declared files/services removed; retained data policy followed |

# 34. Release Metadata

## 34.1 Purpose

Release metadata provides searchable human- and machine-readable identification without replacing the manifest.

## 34.2 General Requirements

`SWBR-META-001` — Metadata shall be generated from controlled inputs and validated against package content and the version manifest.

## 34.3 Required Metadata

Required metadata includes release ID, class, version, creation UTC time, organization, components, targets, profiles, source revision, environment/build ID, compatibility, manifest digest, SBOM identity, signature identity, verification status, licenses, limitations, supersedes/superseded-by, and support status.

## 34.4 Metadata Generation

Generation shall use one controlled schema and shall reject missing required fields, unknown enumerations, duplicate identities, invalid time formats, or inconsistent versions.

## 34.5 Metadata Storage

Metadata shall exist in the release catalog, package, archive inventory, and deployment record as appropriate, with one authoritative manifest reference.

## 34.6 Metadata Validation

Validation shall compare metadata to filenames, internal version reporting, package manager data, manifest, release notes, signatures, and archive path.

## 34.7 Traceability

Metadata shall reference approved changes, evidence summary, audit, and approval record.

## 34.8 Documentation

Field definitions and schema versions shall be controlled and available to release consumers.

## 34.9 Compliance Requirements

`SWBR-META-002` — Human-friendly aliases or channel names shall not replace immutable release and manifest identities.

## Table 34-1. Required Release Metadata

| Metadata group | Examples |
|---|---|
| Identity | Release, version, class, sequence |
| Build | Source, environment, pipeline, profile, target |
| Compatibility | Product, register map, capability, BSP/HAL |
| Assurance | Evidence, audit, approval, deviations |
| Integrity | Manifest, SBOM, digests, signature |
| Lifecycle | Created, published, superseded, retired |

# 35. Version Manifest Requirements

## 35.1 Purpose

The version manifest is the authoritative machine-readable inventory and provenance record for one build or release.

## 35.2 General Requirements

`SWBR-MAN-001` — Each release shall have one canonical manifest whose schema version, content digest, and signature status are recorded.

## 35.3 Required Manifest Contents

The manifest shall include:

- release and component versions, class, profile, target, and compatibility axes;
- all controlling and governing software specification revisions and digests consumed;
- machine-readable Architecture/Register sources, generator identities, and generated-artifact digests;
- source repositories, revisions, submodules, patches, and dirty-state result;
- compiler, linker, analyzer, build system, environment, options, and commands;
- direct and transitive dependencies, licenses, and SBOM reference;
- artifact paths, sizes, media types, roles, and digests;
- tests, analyses, environments, evidence references, outcomes, defects, deviations, and approvals;
- external-host firmware, BSP/HAL, configuration schema, installer, and documentation identities;
- associated FPGA/ASIC hardware identities as separate fields when applicable; and
- Dragon Core `DFC_BUILD_ID` value when an associated hardware image or fabricated device is part of the qualified configuration.

## 35.4 Manifest Generation

The manifest shall be generated from the build graph and verified artifact inventory; manually typed duplicate inventories are prohibited.

## 35.5 Manifest Format

The canonical format shall be a deterministic, schema-validated, UTF-8 machine-readable representation with stable field names and ordering. Human-readable renderings are derived views.

## 35.6 Manifest Validation

Validation shall check schema, uniqueness, references, path normalization, digest recomputation, artifact presence, source resolution, dependency closure, compatibility, evidence, approval, and signature linkage.

## 35.7 Storage and Distribution

The manifest shall be included with the release, stored in the release catalog and archive, and referenced by every deployment record.

## 35.8 Documentation

The schema, field meanings, compatibility axes, and verification procedure shall be published with the release process.

## 35.9 Compliance Requirements

`SWBR-MAN-002` — `dfc_version_pkg.sv` build parameters and `REG-GENART-005` hardware build-manifest data shall be consumed without adding document-tracking state or conflating hardware and software versions.

## Table 35-1. Version Manifest Fields

| Field group | Mandatory content |
|---|---|
| Release | ID, version, class, profile, target |
| Authority | Specifications and source digests |
| Generation | Machine source, generator, outputs |
| Build | Environment, tools, options, commands |
| Supply chain | Dependencies, SBOM, licenses |
| Artifacts | Paths, roles, sizes, digests |
| Assurance | Tests, evidence, anomalies, approvals |
| Compatibility | Software, device, register, capability, platform identities |

# 36. Digital Signature Requirements

## 36.1 Purpose

Digital signatures authenticate approved release content and its manifest at the external release-distribution boundary. They do not create an on-device cryptographic identity or secure-boot function in Dragon Core.

## 36.2 General Requirements

`SWBR-SIGN-001` — Approved production, maintenance, and hotfix releases shall be signed by an authorized organizational signing identity after release approval.

## 36.3 Signing Scope

The signature shall cover the canonical manifest and thereby every digest-identified release artifact. Detached artifact signatures may be added where a distribution format requires them.

## 36.4 Cryptographic Requirements

The release shall identify the approved signature profile, algorithm, parameters, certificate or public-key identity, trust chain where applicable, signing time source, and verification procedure. Deprecated or organization-prohibited algorithms shall not be used.

## 36.5 Key Management

Private keys shall remain in an approved signing service or protected hardware-backed facility, shall not enter source repositories, general build workers, packages, logs, test fixtures, or archives, and shall use role separation, rotation, revocation, backup, and audit controls.

## 36.6 Signature Verification

Verification shall validate manifest bytes, signature, trust identity, validity/revocation status as applicable, release authorization, and artifact digests before installation or use.

## 36.7 Certificate Management

Public verification material, chain, validity, replacement, revocation, and long-term validation information shall be retained with the release record.

## 36.8 Documentation

User and deployment documentation shall provide offline-capable signature and digest verification instructions.

## 36.9 Compliance Requirements

`SWBR-SIGN-002` — Signing authority shall be isolated from unreviewed code execution and from the role that alone authors the release.

`SWBR-SIGN-003` — A signature shall not convert a failed, incomplete, unapproved, or incompatible artifact into an acceptable release.

## Table 36-1. Digital Signature Requirements

| Control | Required outcome |
|---|---|
| Scope | Canonical manifest and identified artifacts |
| Identity | Authorized organizational signer |
| Key custody | Protected service/facility only |
| Verification | Documented and independently executable |
| Revocation | Status and replacement process retained |

# 37. Checksum Requirements

## 37.1 Purpose

Cryptographic digests detect accidental or unauthorized changes and provide content identity for artifacts and records.

## 37.2 General Requirements

`SWBR-HASH-001` — Every released file and canonical manifest shall have a SHA-256 digest at minimum, unless a stricter approved security profile requires another or additional algorithm.

## 37.3 Scope

Digest scope includes executables, libraries, generated definitions, configurations, installers, documentation, manifests, SBOMs, evidence summaries, notices, and archive containers.

## 37.4 Approved Algorithms

Approved algorithms shall be collision-resistant cryptographic hash functions permitted by the current project security profile. Noncryptographic checksums may supplement transport diagnostics but shall not replace release digests.

## 37.5 Checksum Generation

Digests shall be computed over final unsigned bytes or over explicitly identified signed bytes according to the manifest schema. The scope and order shall be unambiguous.

## 37.6 Verification

Digests shall be recomputed after packaging, after signing where the signed object is distributed, after transfer, before installation, during archive integrity checks, and during restoration.

## 37.7 Storage and Distribution

Digests shall reside in the canonical manifest; standalone checksum files shall be derived views and shall identify their manifest.

## 37.8 Documentation

Verification commands or APIs shall be documented without requiring access to private infrastructure.

## 37.9 Compliance Requirements

`SWBR-HASH-002` — A digest mismatch shall fail installation, publication, archive acceptance, or restoration and shall be investigated as an integrity event.

## Table 37-1. Checksum Requirements

| Object | Minimum integrity record |
|---|---|
| Artifact | SHA-256 digest, path, size, role |
| Manifest | SHA-256 digest and signature |
| Archive | Container digest plus contained manifest |
| Transfer | Pre- and post-transfer digest comparison |

# 38. Release Documentation

## 38.1 Purpose

Release documentation enables correct selection, installation, use, recovery, maintenance, verification, and audit of the exact release.

## 38.2 General Requirements

`SWBR-DOCS-001` — Documentation shall be versioned, reviewed, tested against the packaged artifacts, and identified in the manifest.

## 38.3 Required Documentation

Required documents include release notes, compatibility declaration, installation/deployment procedure, rollback procedure, configuration and migration guide, API/operator guide, security and integrity verification, known limitations, licenses/notices, verification summary, support contact/process, and archive/reproduction guide for authorized maintainers.

## 38.4 Release Notes

Release notes shall satisfy Section 39.

## 38.5 Verification Summary

The summary shall identify the exact release configuration, applicable requirements and profiles, results by state, coverage, platform evidence, defects, deviations, residual risk, and approval recommendation without replacing raw evidence.

## 38.6 Deployment Documentation

Deployment documentation shall identify external-host prerequisites, connection and ownership boundaries, package verification, installation, compatibility discovery, configuration, startup, acceptance checks, rollback, and evidence retention.

## 38.7 Archival Requirements

Documentation sources and rendered outputs shall be archived with the release.

## 38.8 Documentation Control

Generated documentation shall record source, generator, options, and digest. Examples and commands shall be executed in validation where practical.

## 38.9 Compliance Requirements

`SWBR-DOCS-002` — Documentation shall not imply ASIC-local software, direct Dragon Core MMIO, software-owned device safety, undocumented access, or installation of executable code into Dragon Core.

## Table 38-1. Required Release Documentation

| Document | Required purpose |
|---|---|
| Release notes | Change and limitation disclosure |
| Compatibility declaration | Correct product/register/platform selection |
| Deployment/rollback | Controlled external-host transition |
| Configuration guide | Safe policy application and restoration |
| Verification summary | Evidence and residual-risk visibility |
| Security/integrity guide | Signature, digest, credentials, and update controls |

# 39. Release Notes Requirements

## 39.1 Purpose

Release notes communicate what changed, what remains compatible, what is known, and what users must do.

## 39.2 General Requirements

`SWBR-NOTES-001` — Release notes shall describe the exact release and shall be generated or checked against approved changes, manifest, defects, and compatibility data.

## 39.3 Required Content

Release ID and date, component versions, release class, supported platforms, device/register compatibility, changes, corrected defects, security updates, deprecated or removed behavior, known issues, residual risk, configuration or schema changes, installation/upgrade/rollback guidance, evidence summary, and support status are required.

## 39.4 Functional Changes

Changes shall reference software requirements and APIs and shall not restate device behavior as a new authority.

## 39.5 Compatibility Information

Compatibility shall list supported Dragon Core product revision, register-map revision/range, required capabilities, device-build restrictions if any, BSP/HAL profiles, API/ABI, persistent-schema, and application-protocol versions.

## 39.6 Known Issues

Known issues shall state impact, affected configurations, detection, workaround or mitigation, residual risk, owner, and planned disposition. Release-blocking issues shall not be disguised as notes.

## 39.7 Installation and Upgrade Guidance

Guidance shall identify prerequisites, data/configuration backup, migration, service interruption, acceptance checks, and rollback triggers.

## 39.8 Documentation Control

Release notes shall be immutable after approval; correction requires an identified erratum or superseding release record.

## 39.9 Compliance Requirements

`SWBR-NOTES-002` — Omission of a known material incompatibility, security limitation, failed required scope, or operationally significant defect is prohibited.

## Table 39-1. Required Release Note Contents

| Content | Required detail |
|---|---|
| Identity | Release, version, class, date |
| Change | Features, fixes, removals, migrations |
| Compatibility | Device, register, capability, API, platform, schema |
| Assurance | Verification status, deviations, residual risk |
| Operation | Install, upgrade, rollback, support |

# 40. Deployment Procedures

## 40.1 Purpose

Deployment installs and activates approved software on an external host and confirms correct interaction with the intended Dragon Core configuration.

## 40.2 General Requirements

`SWBR-DEPLOY-001` — Deployment shall use only an approved release whose signature, manifest, digests, compatibility, and authorization have been verified.

## 40.3 Deployment Preparation

Preparation shall identify target host, BSP/HAL, connected device product/register/build identity, board/integration configuration, current software, configuration and data backups, maintenance window, authority, rollback package, and acceptance procedure.

## 40.4 Deployment Process

The process shall verify the package, stop affected services safely, preserve required software records, install external-host artifacts, migrate configuration/data, restart in a nonoperational or observational state where required, discover device identity, reconcile current device state, apply validated configuration, and enable operation only through the approved workflow.

## 40.5 Post-Deployment Verification

Verification shall cover software version, service health, signature/digests, device compatibility, host readiness, active configuration, diagnostics, event/interrupt service, response-loss handling, persistence, and representative intended-use checks.

## 40.6 Rollback Procedures

Rollback shall be immediately available according to Section 41 when an acceptance criterion fails or a trigger occurs.

## 40.7 Deployment Records

Records shall identify who or what deployed, UTC time, target, prior/new release, manifest, device and board identities, configuration/migration, results, anomalies, approval, and rollback readiness.

## 40.8 Documentation

Procedures shall be tested on each supported deployment class and shall clearly separate host software deployment from Dragon Core volatile configuration application.

## 40.9 Compliance Requirements

`SWBR-DEPLOY-002` — Deployment automation shall not use blind retry for ambiguous state-changing Dragon Core operations and shall preserve required device evidence before destructive service actions.

## Table 40-1. Deployment Procedure Requirements

| Stage | Required outcome |
|---|---|
| Authenticate | Signature, manifest, and digests valid |
| Qualify target | Host/device/platform compatible |
| Preserve | Configuration, records, and rollback baseline available |
| Install | External-host artifacts deployed completely |
| Reconcile/configure | Device state known and active readback confirmed |
| Accept | Post-deployment checks pass |

# 41. Rollback Procedures

## 41.1 Purpose

Rollback restores the last approved external-host software and compatible configuration after a failed or unacceptable deployment.

## 41.2 General Requirements

`SWBR-ROLLBACK-001` — Every production deployment shall have a verified rollback target and procedure before change begins.

## 41.3 Rollback Preconditions

The prior release package, signature verification material, manifest, configuration/data backup, migration reversal or compatibility plan, target credentials, and acceptance procedure shall be available.

## 41.4 Rollback Triggers

Triggers include integrity failure, incompatibility, installation error, service failure, failed active readback, device communication failure, failed acceptance test, unacceptable performance, material security finding, or authorized operator decision.

## 41.5 Rollback Process

Rollback shall place externally effective operation in a safe authorized state, stop affected host services, capture relevant software and device evidence, restore the prior external-host release, restore or migrate configuration/data, reconnect, reconcile device state, reapply validated volatile configuration, and perform acceptance checks.

## 41.6 Post-Rollback Verification

Verification shall confirm software identity, package integrity, service health, device compatibility, active configuration, diagnostic state, data continuity, and correct intended operation.

## 41.7 Rollback Records

Records shall identify trigger, evidence, prior/failed/restored releases, configurations, device identity, actions, outcomes, data disposition, defect, and approval.

## 41.8 Documentation

Rollback limits, irreversible migrations, data loss risks, maximum recovery time objectives where defined, and manual fallback shall be explicit.

## 41.9 Compliance Requirements

`SWBR-ROLLBACK-002` — Rollback shall not assume Dragon Core retains nondefault volatile configuration across reset or power loss.

## Table 41-1. Rollback Procedure Requirements

| Control | Required result |
|---|---|
| Prior baseline | Approved, intact, and available |
| Evidence | Failure state preserved before destructive action |
| Restore | Software and compatible configuration restored |
| Device recovery | State reconciled and volatile configuration confirmed |
| Record | Complete and defect linked |

# 42. Verification Integration

## 42.1 Purpose

Build and release activities consume reviewed software V&V evidence and applicable Verification Plan evidence without redefining methods, cases, outcomes, or technical requirements.

## 42.2 General Requirements

`SWBR-VINT-001` — Release evidence shall correspond to the exact manifest, profile, target, environment, generated definitions, and artifact digests proposed for release.

## 42.3 Verification Integration Points

Integration points include generated-contract consistency, static analysis, unit/integration/system verification, host conformance, FPGA/HIL/post-silicon software evidence, coverage, performance/resource evidence, regression, package/install/rollback validation, and release V&V review.

## 42.4 Quality Gates

Gate ownership and criteria are defined in Section 43. Device-verification case definitions and outcomes remain solely with `RCA-DFC-VP-002`; software V&V criteria remain with `RCA-DFC-SW-005`.

## 42.5 Verification Results Management

Results shall preserve raw evidence, processed summaries, configuration, result state, anomalies, reviewer, and immutable location. Failed, blocked, not-run, not-applicable, waived, and deviated results shall remain distinct from pass.

## 42.6 Traceability

Evidence shall reference governing software requirement IDs and applicable controlling identifiers without copying their normative wording as a second definition.

## 42.7 Exception Handling

A deviation shall identify affected requirement, configuration, evidence, residual risk, mitigation, expiration or review event, owner, and approval. It shall not satisfy a mandatory pass criterion.

## 42.8 Documentation

The release V&V report shall identify the exact release, scope, methods, results, limitations, residual risk, and recommendation.

## 42.9 Compliance Requirements

`SWBR-VINT-002` — A higher-level demonstration shall not override a failed lower-level requirement, wrong oracle, stale generated binding, missing evidence, or unresolved controlling-specification flag.

## Table 42-1. Verification Integration Requirements

| Evidence source | Release use |
|---|---|
| `RCA-DFC-SW-005` results | Software requirement and intended-use acceptance |
| `RCA-DFC-VP-002` results | Controlling device/host-boundary acceptance where applicable |
| Build verification | Artifact and manifest correctness |
| Reproducibility | Independent reconstruction |
| Deployment/rollback validation | Operational transition readiness |

# 43. Quality Gates

## 43.1 Purpose

Quality gates prevent incomplete, inconsistent, insecure, incompatible, or insufficiently verified content from advancing.

## 43.2 General Requirements

`SWBR-GATE-001` — Every gate shall define inputs, checks, decision authority, result states, retained evidence, and failure disposition.

## 43.3 Quality Gate Objectives

Gates establish authority correctness, source quality, build integrity, functional correctness, supply-chain acceptability, compatibility, reproducibility, package readiness, documentation completeness, and approval readiness.

## 43.4 Mandatory Quality Gates

| Gate | Minimum subject |
|---|---|
| G1 Input | Approved change, source, specifications, dependencies, environment |
| G2 Generation | Owner-derived artifacts current and structurally consistent |
| G3 Build | Compile/link and build verification complete |
| G4 Software V&V | Applicable `RCA-DFC-SW-005` exit evidence accepted |
| G5 Platform/host boundary | Applicable `RCA-DFC-VP-002` evidence accepted |
| G6 Supply chain/security | SBOM, license, vulnerability, secret, and integrity review complete |
| G7 Reproducibility | Independent clean rebuild comparison accepted |
| G8 Package/documentation | Inventory, installer, compatibility, notes, deployment, rollback complete |
| G9 Audit/approval | Configuration audit and release authorization complete |

## 43.5 Gate Evaluation

Permitted results are pass, fail, blocked, not applicable with approved basis, or approved deviation where the controlling requirement permits deviation. Only pass satisfies a mandatory no-deviation criterion.

## 43.6 Failure Handling

Failure shall stop promotion, create or update a finding, preserve evidence, identify the owner, and define correction and regression.

## 43.7 Waivers and Exceptions

Waivers shall be bounded to named configurations and requirements. They shall not be used for unresolved controlling ambiguity, release-blocking security, stale generated content, failed integrity, or missing mandatory evidence.

## 43.8 Documentation

Gate records shall identify evaluated baseline, inputs, results, findings, reviewers, decision, conditions, and time.

## 43.9 Compliance Requirements

`SWBR-GATE-002` — Gate aggregation shall not convert a non-pass result to pass by omission, averaging, or management summary.

## Table 43-1. Quality Gate Requirements

| Gate property | Requirement |
|---|---|
| Objective | Based on approved requirements and profiles |
| Reproducible | Same input record permits reevaluation |
| Fail closed | Missing or invalid evidence blocks |
| Reviewable | Raw and processed evidence retained |
| Traceable | Decision tied to exact release manifest |

# 44. Release Approval Process

## 44.1 Purpose

Release approval authorizes a fully identified software release for its declared distribution and use.

## 44.2 General Requirements

`SWBR-APPROVE-001` — Approval shall apply only to the exact manifest digest, release class, profiles, targets, compatibility, evidence, deviations, and distribution scope reviewed.

## 44.3 Release Readiness Assessment

The assessment shall review all gates, audit results, defects, deviations, residual risk, compatibility, security, licenses, documentation, deployment/rollback, archive readiness, and controlling-specification change flags.

## 44.4 Approval Criteria

Approval requires complete configuration identification, passing mandatory evidence, resolved release blockers, accepted residual risk, completed documentation, validated package, reproducibility, integrity protection, and archive readiness.

## 44.5 Approval Authority

At minimum, Software Engineering, Software V&V or Quality, Configuration Management, and the designated Release Authority shall approve according to project governance. Safety, security, platform, or program authorities shall participate when their scope is affected.

## 44.6 Conditional Approval and Exceptions

Conditional approval shall state each condition, excluded conformity claim, affected configuration, mitigation, responsible owner, expiration or closure event, and approving authority. It shall not authorize scope prohibited by a failed mandatory criterion.

## 44.7 Approval Records

Records shall include manifest digest, gate summary, audit, evidence report, defect/deviation list, residual risk, distribution class, approvers, decision, date, and conditions.

## 44.8 Documentation

Approval workflow, quorum, independence, recusals, emergency authority, and revocation shall be controlled.

## 44.9 Compliance Requirements

`SWBR-APPROVE-002` — The author, build executor, or release packager shall not be the sole approver of the release.

`SWBR-APPROVE-003` — Discovery of a material integrity, compatibility, security, or evidence defect after approval shall suspend affected distribution pending disposition.

## Table 44-1. Release Approval Requirements

| Approval input | Required state |
|---|---|
| Manifest/package | Final and internally consistent |
| Gates | Applicable mandatory gates passed |
| Defects/deviations | Visible, bounded, and accepted or closed |
| Documentation | Complete and validated |
| Deployment/rollback | Ready and tested |
| Archive | Ready for immutable retention |

# 45. Configuration Audits

## 45.1 Purpose

Configuration audits prove that the release is functionally represented by its approved evidence and physically represented by its manifest and package.

## 45.2 General Requirements

`SWBR-AUDIT-001` — An audit shall use the final candidate bytes and canonical manifest proposed for approval.

## 45.3 Audit Types

The Functional Configuration Audit (FCA) examines requirements, behavior, verification, anomalies, deviations, and documentation. The Physical Configuration Audit (PCA) examines source, generated artifacts, tools, dependencies, artifact inventory, versions, digests, package, manifest, SBOM, signatures, and archive inputs.

## 45.4 Audit Scope

Scope shall include every component, profile, target, associated hardware identity, evidence set, installer, document, license, and distribution channel in the release claim.

## 45.5 Audit Procedures

Procedures shall resolve every manifest entry, recompute digests, compare package inventory, confirm release tag/source, regenerate or compare generated artifacts, verify environment and commands, inspect profile isolation, review evidence trace, and confirm approvals.

## 45.6 Audit Findings

Findings shall be classified, owned, corrected or dispositioned, regression assessed, and linked to the release decision.

## 45.7 Audit Records

Records shall identify auditors, independence, baseline, checklist, evidence, findings, resolution, rerun, decision, and date.

## 45.8 Documentation

Audit checklists shall be version controlled and tailored by release class without omitting mandatory subjects.

## 45.9 Compliance Requirements

`SWBR-AUDIT-002` — An unresolved mismatch among manifest, package, source, generated definitions, evidence, documentation, or approval is release blocking.

## Table 45-1. Configuration Audit Requirements

| Audit question | Required answer |
|---|---|
| Does evidence cover the claimed functions/configurations? | Yes |
| Can every package item be traced to an approved build? | Yes |
| Do regenerated definitions match released definitions? | Yes |
| Are production and engineering contents separated? | Yes |
| Do manifest, SBOM, digests, notes, and archive agree? | Yes |

# 46. Archive Requirements

## 46.1 Purpose

The release archive preserves the content and information required to authenticate, reproduce, understand, deploy, roll back, maintain, and audit an approved release.

## 46.2 General Requirements

`SWBR-ARCHIVE-001` — The archive shall be immutable after acceptance; corrections shall create a new archive version and audit record.

## 46.3 Archive Scope

The archive shall include specifications and profiles consumed; source and submodules; machine-readable definitions; generators and generated outputs; dependencies and source where required; environment and toolchain; commands/options; unsigned and signed artifacts; packages; manifest; SBOM; digests; signature material; tests and raw/processed evidence; defects/deviations; documentation; approvals; deployment/rollback procedures; and audit records.

## 46.4 Archive Organization

Archive organization shall preserve release, component, profile, target, and evidence boundaries and shall contain an index whose digest is recorded.

## 46.5 Retention Requirements

Retention shall follow Section 47 and applicable contractual, legal, safety, security, and records policies.

## 46.6 Archive Integrity

Archive ingestion and periodic monitoring shall verify signatures, digests, readability, media health, redundancy, access controls, and metadata consistency.

## 46.7 Archive Retrieval

Authorized retrieval shall restore the complete baseline without altering the retained copy and shall record requester, purpose, time, content, and integrity outcome.

## 46.8 Documentation

The archive shall include restore, reproduction, signature validation, dependency reconstruction, and media-migration procedures.

## 46.9 Compliance Requirements

`SWBR-ARCHIVE-002` — An archive is not accepted until a representative restoration and manifest/digest verification succeeds.

## Table 46-1. Archive Requirements

| Archive property | Requirement |
|---|---|
| Completeness | Reproduction, evidence, deployment, and audit content retained |
| Immutability | Approved bytes cannot be silently replaced |
| Integrity | Digests/signatures monitored |
| Availability | Redundant controlled storage |
| Restorability | Periodically demonstrated |

# 47. Long-Term Retention Requirements

## 47.1 Purpose

Long-term retention preserves release support and conformity evidence throughout the required lifecycle.

## 47.2 General Requirements

`SWBR-RETAIN-001` — Reproduction-critical release records shall be retained for the supported product life and for at least ten years after the last supported deployment, unless a contract, law, safety policy, or records schedule requires longer.

## 47.3 Retained Artifacts

Retained items include all archive scope in Section 46 plus supersession, retirement, vulnerability, incident, field-support, migration, and revocation records affecting the release.

## 47.4 Retention Periods

The approved records schedule shall define periods by record class, release class, customer/contract, legal hold, and product-support status. Destruction is prohibited while any longer applicable obligation or hold exists.

## 47.5 Storage Requirements

Storage shall provide redundancy, geographic or failure-domain separation, encryption where required, access control, format sustainability, integrity monitoring, backup, and media migration.

## 47.6 Retrieval Requirements

The project shall define maximum retrieval objectives appropriate to support and incident-response needs and shall test representative retrieval at scheduled intervals.

## 47.7 Integrity Monitoring

Digest verification, signature/trust-material preservation, media checks, restoration tests, and migration audits shall be scheduled and recorded.

## 47.8 Documentation

Retention schedules, legal holds, access, migration, restoration, and authorized disposal shall be documented.

## 47.9 Compliance Requirements

`SWBR-RETAIN-002` — Disposal shall require authorization, proof that no hold or support obligation remains, secure destruction appropriate to classification, and an immutable disposal record.

## Table 47-1. Long-Term Retention Requirements

| Record class | Minimum basis |
|---|---|
| Release reproduction | Product support life plus ten years |
| Verification/approval | Same as supported conformity claim or longer obligation |
| Security incident/revocation | Security and legal schedule |
| Customer/contract records | Contractual schedule |
| Legal hold | Until formal release of hold |

# 48. Security Requirements

## 48.1 Purpose

Security controls protect source, build infrastructure, dependencies, artifacts, credentials, approvals, distribution, and archives while preserving the PBIO-defined external software boundary.

## 48.2 General Requirements

`SWBR-SEC-001` — Build and release privileges shall follow least privilege, separation of duties, strong authentication, auditable authorization, and timely revocation.

## 48.3 Access Control

Repository administration, protected merge, release build, deviation approval, signing, publication, archive administration, and deployment authorization shall be separate roles where practical.

## 48.4 Credential Management

Credentials shall be scoped, short lived where possible, centrally managed, rotated, revoked, redacted from logs, excluded from packages, and unavailable to untrusted build steps.

## 48.5 Secure Build Environment

Release builds shall use approved workers, verified environment images, controlled ingress, restricted egress, dependency integrity, isolated workspaces, tamper-evident logs, and cleanup of secrets and transient data.

## 48.6 Artifact Protection

Artifacts shall use content digests, immutable storage, restricted promotion, signatures, authenticated distribution, and verification before use.

## 48.7 Security Monitoring

Monitoring shall cover unauthorized access, branch/tag changes, credential use, dependency changes, signing, publication, integrity failures, anomalous builds, and archive events.

## 48.8 Documentation

The security profile shall identify threat assumptions, trust boundaries, roles, secrets, incident response, vulnerability handling, revocation, and recovery.

## 48.9 Compliance Requirements

`SWBR-SEC-002` — Release packages shall contain no secret key, plaintext credential, unrestricted test authorization, undocumented access mechanism, or customer operational secret.

`SWBR-SEC-003` — External package signatures, host authentication, and update security shall not be represented as Dragon Core secure boot, key storage, cryptographic identity, or an on-device software trust boundary.

## Table 48-1. Security Requirements

| Asset | Primary controls |
|---|---|
| Source/baselines | Access, review, protected history |
| Dependencies | Provenance, pinning, integrity, vulnerability review |
| Build workers | Isolation, least privilege, restricted network |
| Signing | Protected keys and separated authority |
| Distribution | Immutable authenticated content |
| Archive | Access, encryption where required, integrity, restoration |

# 49. Traceability Requirements

## 49.1 Purpose

Traceability connects each release claim to its authority, implementation, build, verification, package, approval, deployment, and maintenance history.

## 49.2 General Requirements

`SWBR-TRACE-001` — Every normative `SWBR-*` requirement shall be unique and shall trace to implementation or process evidence and a verification, review, or audit disposition.

## 49.3 Traceability Scope

Trace shall cover governing requirements, approved changes, source, generated artifacts, APIs, configuration schemas, tests, tools, dependencies, build steps, artifacts, evidence, defects, deviations, documentation, manifests, approvals, deployments, rollbacks, and archives.

## 49.4 Traceability Mechanisms

Stable identifiers and machine-readable links shall be preferred. Directory location, filename similarity, branch name, or textual resemblance is insufficient.

## 49.5 Requirements Traceability

Software requirements shall trace downstream to component design, source, tests, results, and released artifacts and upstream to the applicable software-architecture and controlling identifiers consumed.

## 49.6 Configuration Traceability

Each artifact shall trace through its manifest to exact source, generator, generated bindings, environment, toolchain, dependencies, options, profile, target, and package transformation.

## 49.7 Traceability Verification

Automated and reviewed checks shall detect unresolved IDs, duplicate IDs, orphan requirements, orphan production behavior, stale links, unrepresented artifacts, and evidence/configuration mismatches.

## 49.8 Documentation

Trace reports shall state scope, source systems, generation time, unresolved items, exclusions, and manifest identity.

## 49.9 Compliance Requirements

`SWBR-TRACE-002` — This software trace shall not recreate or modify the controlling SRS-to-Architecture-to-Register-to-RTL-to-Verification relationships owned by `RCA-DFC-RTM-002`.

## Table 49-1. Traceability Requirements

| From | Required links |
|---|---|
| Software requirement | Design/source/test/result/release artifact |
| Generated artifact | Normative machine source/generator/output digest |
| Build artifact | Source/environment/options/dependencies/profile |
| Evidence | Requirement/case/configuration/artifact/verdict |
| Release | Changes/artifacts/evidence/defects/approval/deployment |

# 50. Deliverables

## 50.1 Purpose

Deliverables comprise the complete approved software release and the records required to use, verify, maintain, reproduce, and audit it.

## 50.2 General Requirements

`SWBR-DEL-001` — Every deliverable shall be complete, internally consistent, validated, ready for its declared use, and identified in the canonical manifest.

## 50.3 Software Deliverables

Applicable deliverables include external-host executables, firmware images, static/shared libraries, public headers, BSPs/HALs, drivers, SDK, applications, configuration schemas, migration tools, installers, diagnostics, and maintenance tools.

## 50.4 Build and Release Deliverables

Source, machine-readable definitions, generators, generated artifacts, build system, environment definition, toolchain configuration, dependency lock/inventory, SBOM, manifests, packages, digests, signatures, audit records, and release catalog records are required according to applicability.

## 50.5 Verification Deliverables

Tests, models, fixtures, data, raw/processed results, coverage, software V&V report, applicable Verification Plan evidence references, reproducibility results, package/install/rollback validation, anomalies, deviations, and residual-risk records shall be delivered or archived.

## 50.6 Configuration Management Deliverables

Change records, baseline records, status accounting, trace reports, FCA/PCA records, approval, deployment, rollback, supersession, retirement, and archive inventories are required.

## 50.7 Documentation Deliverables

API, integration, configuration, compatibility, security, install, deployment, rollback, release notes, licenses/notices, support, archive, and reproduction documentation shall be included as applicable.

## 50.8 Delivery Media

Media or channels shall be authorized, integrity protected, access controlled, and capable of preserving filenames, permissions, metadata, manifest, digests, and signatures.

## 50.9 Compliance Requirements

`SWBR-DEL-002` — Associated FPGA/ASIC hardware images and physical integration records shall retain separate identities and ownership even when distributed in the same controlled bundle.

`SWBR-DEL-003` — No deliverable shall imply executable software inside Dragon Core or replace on-device evidence with an external software record.

## Table 50-1. Required Deliverables

| Deliverable class | Minimum contents |
|---|---|
| Software | External-host artifacts and configurations |
| Provenance | Source, generation, tools, dependencies, manifest, SBOM |
| Assurance | Results, coverage, anomalies, deviations, approvals |
| Documentation | Use, compatibility, security, deployment, rollback |
| Lifecycle | Audit, archive, deployment, support, retirement |

# 51. Exit Criteria

## 51.1 Purpose

Exit criteria define when a software release is complete for its declared class, profile, targets, compatibility, and use.

## 51.2 General Requirements

Revision B compliance for a release is complete only when:

- every applicable `SWBR-*` requirement has an approved disposition;
- every normative identifier is unique and every required reference resolves;
- no ASIC-local firmware, processor, direct MMIO, Dragon Core linker map, software boot memory, or executable installation into Dragon Core is implied;
- source, generated definitions, public APIs, configurations, documentation, packages, manifests, SBOMs, and release metadata are mutually consistent;
- generated host definitions match the approved Architecture/Register machine sources and generator manifest;
- all source, dependencies, tools, environment, options, profiles, targets, and artifacts are uniquely identified;
- required build, static-analysis, unit, integration, system, host-conformance, platform, HIL, post-silicon, package, installation, deployment, rollback, and regression evidence is complete for the claimed scope;
- applicable `RCA-DFC-SW-005` and `RCA-DFC-VP-002` evidence is accepted without redefining its authority;
- production and engineering capabilities are demonstrably isolated;
- ambiguous state-changing operations have reconciliation, readback, retry-refusal, and recovery evidence where applicable;
- reproducibility comparison passes or every approved bounded nondeterministic field is documented and semantically verified;
- dependency, license, provenance, vulnerability, secret, integrity, and signing reviews pass;
- compatibility across software, API/ABI, schema, product revision, register-map revision, capability, device build, BSP/HAL, and platform axes is explicit;
- release notes, deployment, rollback, security, support, and archive documentation are complete and validated;
- FCA/PCA, release approval, signing, publication, and archive acceptance are complete; and
- no failed mandatory gate, release-blocking defect, unexplained nondeterminism, missing evidence, integrity mismatch, or unresolved controlling-specification change flag remains.

## 51.3 Build Completion

`SWBR-EXIT-001` — The final release bytes shall be produced by the approved build graph from the identified baseline and shall pass build verification.

## 51.4 Verification Completion

`SWBR-EXIT-002` — Every required result shall be a true reviewed pass for the exact release configuration; blocked, not-run, failed, waived, deviated, and not-applicable states shall remain explicit.

## 51.5 Configuration Completion

The manifest shall resolve every source, generated, tool, dependency, artifact, evidence, and approval item without mismatch.

## 51.6 Documentation Completion

All required documentation shall be complete, internally consistent, tested, and bound to the release manifest.

## 51.7 Approval Completion

Required authorities shall approve the exact final manifest digest and distribution scope.

## 51.8 Archive Completion

The final release, reproduction baseline, evidence, approvals, and documentation shall be archived and a representative restoration shall pass.

## 51.9 Compliance Requirements

`SWBR-EXIT-003` — A release may claim conformity only for the exact profiles, targets, compatibility, evidence, and distribution scope approved.

## Table 51-1. Exit Criteria Summary

| Exit criterion | Acceptance requirement |
|---|---|
| Build | Controlled, clean, verified, reproducible |
| Verification | Applicable required evidence passed and reviewed |
| Configuration | Manifest, package, source, and evidence agree |
| Security/supply chain | Integrity, signing, SBOM, license, findings accepted |
| Documentation | Complete and validated |
| Approval | Exact final manifest authorized |
| Archive | Complete, intact, and restorable |

# 52. Baseline Statement

## 52.1 Purpose

This section establishes Revision B as the governing software build-and-release baseline beneath the eight controlling Dragon Flight specifications.

## 52.2 Baseline Declaration

RCA-DFC-SW-006 Revision B supersedes Revision A for all new Dragon Flight external-host software build, packaging, release, deployment, rollback, archival, and maintenance activity supporting Dragon Core Revision A.

## 52.3 Configuration Control

`SWBR-BASE-001` — Changes to this specification shall use formal change control, impact analysis, review, revision history, and baseline approval.

## 52.4 Revision Management

Each revision shall retain traceability to the superseded baseline and shall identify affected processes, artifacts, releases, tools, environments, compatibility, verification, records, and training.

## 52.5 Applicability

This baseline applies to external embedded-host firmware, HAL/BSP/driver software, SDKs, services, applications, generators, generated bindings, software verification tools, manufacturing and maintenance software, packages, installers, documentation, release evidence, deployment, rollback, and archives.

## 52.6 Governing Authority

This specification remains subordinate to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, and `RCA-DFC-RTL-STD-002`. It implements the software subjects of `RCA-DFC-SW-001` Revision C and `RCA-DFC-SW-002` through `RCA-DFC-SW-005` Revision B.

## 52.7 Effective Date

This baseline becomes effective upon formal approval. Approval of this specification does not approve a particular software release; each release requires its own manifest, evidence, audit, approval, signature, publication, deployment, and archive records.

## 52.8 Future Revisions

`SWBR-BASE-002` — A future change requiring new product scope, boundary allocation, device behavior, hardware architecture, register meaning, device-verification definition, controlling trace relationship, or RTL rule shall first revise the applicable controlling owner.

## 52.9 Compliance Statement

The eight controlling specifications provide a complete, consistent technical basis for this Revision B software build-and-release baseline. No change to `RCA-DFC-CHTR-002`, `RCA-DFC-PBIO-002`, `RCA-DFC-SRS-002`, `RCA-DFC-ARCH-002`, `RCA-DFC-REG-002`, `RCA-DFC-VP-002`, `RCA-DFC-RTM-002`, or `RCA-DFC-RTL-STD-002` is required.

Historical Revision A assumptions of on-device firmware, RISC-V or other internal processing, direct MMIO, Dragon Core memory/linker maps, firmware programming into the ASIC, Caravel, or software ownership of device verification are superseded and shall not be restored.

## Table 52-1. Baseline Approval Requirements

| Subject | Revision B conclusion |
|---|---|
| Product boundary | External-host software only; no executable component inside Dragon Core |
| Host access | SRS-defined SPI and Register-Map-defined logical contract |
| Build identity | Software release/build identity remains distinct from device `BUILD_ID` |
| FPGA/ASIC packages | External-host software with separately owned hardware identities |
| Authority | Eight-document hierarchy and single-owner rules preserved |
| Controlling-specification changes | None required |
| Superseded document | `RCA-DFC-SW-006`, Revision A |
| Approval effect | Governs future build/release activity; does not approve a specific release |
