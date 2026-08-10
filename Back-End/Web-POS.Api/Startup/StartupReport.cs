namespace Api.Startup;

/// <summary>
/// The handful of facts the startup banner shows.
///
/// It exists because the two halves happen at different times: the checks run
/// against the databases BEFORE the server starts, while the URLs are not known
/// until it is listening. This carries the first half across to the second.
/// </summary>
public sealed class StartupReport
{
    public bool AppDatabaseConnected { get; set; }
    public bool MasterDatabaseConnected { get; set; }

    /// <summary>False when the AdminUser table could not be created or seeded — every /admin sign-in will fail.</summary>
    public bool AdminPortalReady { get; set; }

    /// <summary>Where the session/antiforgery keys live. Decides whether a restart signs everyone out.</summary>
    public string DataProtectionKeyStore { get; set; } = string.Empty;

    /// <summary>Set while an admin account still carries the password published in the source.</summary>
    public bool AdminPortalOnDefaultPassword { get; set; }

    /// <summary>
    /// Drives the one-line hint pointing at the full configuration dump. Only
    /// worth showing when something actually looks wrong — otherwise it is one
    /// more line of noise on a healthy boot.
    /// </summary>
    public bool HasProblems =>
        !AppDatabaseConnected || !MasterDatabaseConnected || !AdminPortalReady;
}
