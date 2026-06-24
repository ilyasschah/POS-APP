using System.Security.Cryptography;
using Microsoft.IdentityModel.Tokens;

namespace Api.Master.Services
{
    /// <summary>
    /// Holds the RSA keypair used to sign offline subscription leases (Pillar 2).
    /// The PRIVATE key signs leases server-side; the app verifies with the PUBLIC
    /// key (served by <c>/api/Master/LeasePublicKey</c>) so it can validate a lease
    /// fully offline and cannot forge <c>validUntil</c>.
    ///
    /// Key source, in order: <c>Lease:PrivateKeyPem</c> config → a persisted file →
    /// generate + persist (dev convenience). In production, supply the key from a
    /// real secret store via config and rotate per the ADR-002 guidance.
    /// </summary>
    public sealed class LeaseKeyService
    {
        private readonly RSA _rsa;
        public RsaSecurityKey SigningKey { get; }
        public string PublicKeyPem { get; }

        public LeaseKeyService(IConfiguration config, IHostEnvironment env, ILogger<LeaseKeyService> logger)
        {
            _rsa = RSA.Create(2048);

            var configuredPem = config["Lease:PrivateKeyPem"];
            var keyPath = Path.Combine(env.ContentRootPath, "lease_signing_key.pem");

            if (!string.IsNullOrWhiteSpace(configuredPem))
            {
                _rsa.ImportFromPem(configuredPem);
            }
            else if (File.Exists(keyPath))
            {
                _rsa.ImportFromPem(File.ReadAllText(keyPath));
            }
            else
            {
                File.WriteAllText(keyPath, _rsa.ExportRSAPrivateKeyPem());
                logger.LogWarning(
                    "Generated a new lease signing key at {path}. For production, supply " +
                    "Lease:PrivateKeyPem from a secret store instead.", keyPath);
            }

            SigningKey = new RsaSecurityKey(_rsa) { KeyId = "lease-rsa-1" };
            PublicKeyPem = _rsa.ExportSubjectPublicKeyInfoPem();
        }
    }
}
