using System;

namespace Api.Attributes
{
    /// <summary>
    /// Exempts an action (or a whole controller) from the tenant check performed
    /// by <c>CompanyScopeFilter</c>.
    ///
    /// ⚠️ Every use is a deliberate decision that this endpoint may act on a
    /// company OTHER than the caller's own, and each one needs its own reason in
    /// a comment. The control plane genuinely does — listing tenants, provisioning
    /// a new company, checking a device seat during master login all happen either
    /// before a company is chosen or across all of them. Nothing a POS terminal or
    /// the owner dashboard calls should ever carry this.
    /// </summary>
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
    public sealed class AllowCrossCompanyAttribute : Attribute
    {
    }

    /// <summary>
    /// Names EXTRA parameters that carry a company id under a different name, so
    /// they are checked too.
    ///
    /// The filter finds <c>companyId</c> on its own. This exists for the handful
    /// of endpoints that call it something else — <c>CompanyController</c> scopes
    /// by a plain <c>id</c>, which everywhere else in the API means a product, a
    /// document or a user, so it cannot be matched by name alone.
    /// </summary>
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
    public sealed class CompanyScopedByAttribute : Attribute
    {
        public CompanyScopedByAttribute(params string[] parameterNames)
        {
            ParameterNames = parameterNames ?? Array.Empty<string>();
        }

        public string[] ParameterNames { get; }
    }
}
