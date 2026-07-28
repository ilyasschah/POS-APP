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
    ///
    /// Configuration problems (absent/corrupt key, unwritable content root) are
    /// detected at startup by <see cref="Api.Configuration.StartupConfigurationValidator"/>,
    /// which aborts the host outside Development rather than letting them surface
    /// as a 500 on the first login.
    /// </summary>
    public sealed class LeaseKeyService : IDisposable
    {
        private readonly RSA _rsa;
        public RsaSecurityKey SigningKey { get; }
        public string PublicKeyPem { get; }

        public LeaseKeyService(IConfiguration config, IHostEnvironment env, ILogger<LeaseKeyService> logger)
        {
            var configuredPem = config["Lease:PrivateKeyPem"];
            var keyPath = Path.Combine(env.ContentRootPath, "lease_signing_key.pem");

            _rsa = RSA.Create();

            if (!string.IsNullOrWhiteSpace(configuredPem))
            {
                // Explicit configuration — a parse failure here is a real
                // misconfiguration and must not be papered over with a fresh key,
                // which would silently invalidate every lease already issued.
                _rsa.ImportFromPem(configuredPem);
                logger.LogInformation("Lease signing key loaded from configuration (Lease:PrivateKeyPem).");
            }
            else if (File.Exists(keyPath))
            {
                _rsa.ImportFromPem(File.ReadAllText(keyPath));
                logger.LogInformation("Lease signing key loaded from {path}.", keyPath);
            }
            else
            {
                _rsa.KeySize = 2048;
                // Persisting is best-effort. A read-only content root (common under
                // IIS) previously threw straight out of this constructor — and because
                // the service is a lazily-resolved singleton, that surfaced as a 500 on
                // the first login rather than at startup. Degrade to an in-memory key
                // and complain loudly instead of taking authentication down.
                try
                {
                    File.WriteAllText(keyPath, _rsa.ExportRSAPrivateKeyPem());
                    logger.LogWarning(
                        "Generated a new lease signing key at {path}. For production, supply " +
                        "Lease:PrivateKeyPem from a secret store instead.", keyPath);
                }
                catch (Exception ex)
                {
                    logger.LogError(ex,
                        "Generated a new lease signing key but COULD NOT PERSIST it to {path}. " +
                        "The key exists in memory only, so every restart will invalidate all " +
                        "previously issued leases and force clients to re-sync. Grant the " +
                        "application identity write access to the content root, or set " +
                        "Lease:PrivateKeyPem.", keyPath);
                }
            }

            SigningKey = new RsaSecurityKey(_rsa) { KeyId = "lease-rsa-1" };
            PublicKeyPem = _rsa.ExportSubjectPublicKeyInfoPem();
        }

        public void Dispose() => _rsa.Dispose();
    }
}
