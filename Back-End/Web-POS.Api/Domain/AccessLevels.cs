using System.Collections.Generic;

namespace Api.Domain
{
    /// <summary>
    /// What <see cref="User.AccessLevel"/>'s numbers mean. **0 is Admin.**
    /// </summary>
    /// <remarks>
    /// 🚨 This exists because the admin portal got it backwards and shipped.
    /// Three forms, two conventions, in one portal: `Users/Edit` offered
    /// `0 = Admin` (right), while `Companies/Create` and `Companies/Details`
    /// offered `1 = Admin` (wrong) — and the user list on Details rendered its
    /// badge the same wrong way, so the portal CONFIRMED the lie back to you.
    /// Creating a company's first "Admin" from the portal produced a cashier who
    /// could not open Management, and nothing said so until they tried at a
    /// till.
    ///
    /// The ordering is not arbitrary and cannot be changed: 0 is the value the
    /// whole system reads as "unrestricted". `SecurityGuard.canAccess` returns
    /// true immediately for `accessLevel == 0` without consulting a single rule,
    /// the POS user list prints `accessLevel == 0 ? Admin : Cashier`, and the
    /// owner dashboard's `isAdmin` is `accessLevel == 0`. A new row defaults to
    /// 0, so an unset access level is an ADMIN — which is why every form must
    /// state it explicitly rather than relying on the default.
    ///
    /// Anything that shows or sets a role goes through here. A hardcoded 0 or 1
    /// in a view is how the portal ended up disagreeing with itself.
    /// </remarks>
    public static class AccessLevels
    {
        /// <summary>Universal access. Every security rule is skipped.</summary>
        public const int Admin = 0;

        /// <summary>Access only where the company's rule allows it (level 0).</summary>
        public const int Cashier = 1;

        /// <summary>The label for a stored level. Unknown values read as Cashier —
        /// fail-restrictive, matching what the guard actually does with them.</summary>
        public static string Name(int accessLevel) =>
            accessLevel == Admin ? "Admin" : "Cashier";

        /// <summary>The two choices, in the order a form should list them.
        /// Bind a dropdown to this instead of writing the numbers again.</summary>
        public static IReadOnlyList<(int Value, string Label)> Options { get; } =
        [
            (Admin, "Admin"),
            (Cashier, "Cashier"),
        ];
    }
}
