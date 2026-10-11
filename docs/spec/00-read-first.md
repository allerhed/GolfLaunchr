## 0. Read this first

**Document:** Product and feature specification, implementation contracts, agent work packages, and validation plan. **Version:** 1.7. **Research date:** 11 October 2026. **Document language:** English. **Launch app languages:** English (`en`) and Swedish (`sv`). **Working name:** GolfLaunchr. **Reference product:** ShotVision. **Target:** an independently designed iPhone application with comparable publicly documented product capabilities.

This handover is complete as a specification of the publicly discoverable scope. It is not a certification of exact installed-app parity. Research used the live marketing site, current US and Swedish App Store listings, release notes, official Apple documentation, and a historical hands-on review. No physical iPhone session, purchase flow, simulator connection, or accuracy experiment was executed during this research. Undocumented behaviours have explicit original defaults or release gates below. An agent must never translate “documented by the vendor” into “independently tested”.

The essential risk is measurement, not UI delivery. A working practice dashboard driven by synthetic numbers is a prototype. It is not a launch monitor. Release completion requires real capture, calibrated measurement, independently collected validation data, durable storage, and end-to-end tests on supported physical devices.

### How the implementation team should use this file

1. Read sections 0–5 before writing code. Adopt the original defaults unless the product owner deliberately changes them.
2. Implement G0–G2 before committing to supported devices or paid measurement claims.
3. Use feature IDs F01–F25, contracts, and test IDs as issue and pull-request references.
4. Follow work packages in section 10. Keep research provenance separate from the independently authored code.
5. Treat every unexecuted validation as NOT RUN. Implemented, verified, and released are separate states.
6. Full scope means F01–F25 and all applicable gates. A core-only build must explicitly identify omitted parity features.
