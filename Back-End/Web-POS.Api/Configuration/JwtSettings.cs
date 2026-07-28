namespace Api.Configuration;

/// <summary>
/// Single source of truth for the JWT signing secret, issuer and audience.
///
/// This exists because all three are needed in two places — token *issuance*
/// (<see cref="Api.Services.TokenService"/>) and token *validation* (the
/// JwtBearer setup in Program.cs). If those two ever resolve a value
/// differently the API signs tokens it then rejects, which presents as every
/// login succeeding and every subsequent request 401-ing. Routing both through
/// this class makes that class of bug impossible.
/// </summary>
public static class JwtSettings
{
    /// <summary>
    /// Last-resort secret so a fresh clone runs in Development with no setup.
    /// Never reachable outside Development — <see cref="StartupConfigurationValidator"/>
    /// aborts startup first.
    /// </summary>
    public const string DevelopmentFallbackSecret = "dev-only-very-long-secret-change-me-please";

    public const string DefaultIssuer = "Products.Api";
    public const string DefaultAudience = "Products.Clients";

    /// <summary>Default token lifetime: 7 days, in minutes.</summary>
    public const int DefaultExpireMinutes = 10080;

    /// <summary>Secrets that are known to be examples, not real values.</summary>
    public static readonly string[] KnownPlaceholders =
    {
        "change-this-to-a-long-random-secret-32plus-characters",
        DevelopmentFallbackSecret,
    };

    /// <summary>Minimum length for an HMAC-SHA256 signing key worth trusting.</summary>
    public const int MinimumSecretLength = 32;

    /// <summary>
    /// Resolves the effective signing secret.
    ///
    /// NOTE every resolver here tests <see cref="string.IsNullOrWhiteSpace"/> rather
    /// than using <c>??</c>. appsettings.json ships <c>"Secret": ""</c>, and the JSON
    /// configuration provider surfaces that as an *empty string*, not null — so the
    /// previous <c>config["Jwt:Secret"] ?? fallback</c> never fired the fallback and
    /// instead produced a zero-length key, which throws
    /// <c>IDX10703: key length is zero</c> deep inside the token handler.
    /// </summary>
    public static string ResolveSecret(IConfiguration config) =>
        Coalesce(config["Jwt:Secret"], DevelopmentFallbackSecret);

    public static string ResolveIssuer(IConfiguration config) =>
        Coalesce(config["Jwt:Issuer"], DefaultIssuer);

    public static string ResolveAudience(IConfiguration config) =>
        Coalesce(config["Jwt:Audience"], DefaultAudience);

    public static int ResolveExpireMinutes(IConfiguration config) =>
        int.TryParse(config["Jwt:ExpireMinutes"], out var minutes) && minutes > 0
            ? minutes
            : DefaultExpireMinutes;

    private static string Coalesce(string? value, string fallback) =>
        string.IsNullOrWhiteSpace(value) ? fallback : value;
}
