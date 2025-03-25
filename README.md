# Diogo's Master Thesis

// TODO

## Documents

All deliverables of this project, including compiled [Typst] documents,
can be found in the [releases tab] of this repository.
Each file is accompanied with a GPG signature (`.asc` files), which can be verified
using my public key at [gpg.diogotc.com].

<details>
<summary>Verification Instructions</summary>

1. Download my public key and import it into the GPG keystore:

   ```sh
   curl https://gpg.diogotc.com | gpg --import
   ```
2. (Optional) Validate that the fingerprint matches
   `111F 91B7 5F61 99D8 985B  4C70 12CF 31FD FF17 2B77`.
   You can view the fingerprint of all keys in your keyring using `gpg -k`.
3. Download file and signature from the releases tab.
4. Validate the signature using `gpg --verify <filename>.asc`.

</details>

## License

All the code is licensed under the [GPLv3 license](./LICENSE.md), while the
documents in the `docs` directory are licensed under
[CC-BY-SA-4.0](./docs/LICENSE.md).

[Typst]: https://typst.app/
[releases tab]: https://github.com/diogotcorreia/master-thesis/releases
[gpg.diogotc.com]: https://gpg.diogotc.com
