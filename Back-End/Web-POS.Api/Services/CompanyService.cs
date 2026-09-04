using Api.DataBase;
using Api.Domain;
using Api.Master.Services;
using Api.Models;
using Api.Repository;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Api.Services;

public class CompanyService
{
    /// <summary>Defaults a brand-new (trialing) company is provisioned with when
    /// the request doesn't specify them.</summary>
    private const int DefaultTrialSeats = 5;
    private const int DefaultTrialDays = 30;

    public readonly CompanyRepository _companyRepository;
    public readonly CountryRepository _countryRepository;
    private readonly AppDbContext _db;
    private readonly ITenantProvisioningService _provisioning;
    private readonly ILogger<CompanyService> _logger;

    public CompanyService(
        CompanyRepository companyRepository,
        CountryRepository countryRepository,
        AppDbContext db,
        ITenantProvisioningService provisioning,
        ILogger<CompanyService> logger)
    {
        _companyRepository = companyRepository;
        _countryRepository = countryRepository;
        _db = db;
        _provisioning = provisioning;
        _logger = logger;
    }

    public async Task<CompanyDto> Create(CreateCompanyRequest req)
    {
        if (await _companyRepository.GetByNameAsync(req.Name) != null)
            throw new InvalidOperationException($"A Company with the name '{req.Name}' already exists.");

        // Create the company AND its baseline data (default warehouse, C000
        // walk-in customer, S000 supplier, payment types, settings, security
        // keys, printer rows) atomically — a new company is never left without
        // the defaults it needs to start up. Wrapped in the execution strategy
        // because the context uses retry-on-failure (which forbids a bare user
        // transaction). CRITICAL: the entity is built fresh and the change
        // tracker cleared at the START of each attempt, so a retried attempt
        // never re-saves entities left tracked by a previous failed attempt —
        // that accumulation caused duplicate-key crashes (e.g. seeding the same
        // SecurityKey / printer rows twice) under retry.
        Company newEntity = null!;
        var createStrategy = _db.Database.CreateExecutionStrategy();
        await createStrategy.ExecuteAsync(async () =>
        {
            _db.ChangeTracker.Clear();

            newEntity = Company.Create(
                req.Name, req.CountryId, req.Address, req.PostalCode, req.City,
                req.TaxNumber, req.Email, req.PhoneNumber, req.BankAccountNumber,
                req.BankDetails, req.StreetName, req.AdditionalStreetName,
                req.BuildingNumber, req.PlotIdentification, req.CitySubdivisionName,
                req.CountrySubentity);

            await using var tx = await _db.Database.BeginTransactionAsync();
            await _companyRepository.AddAsync(newEntity);
            await CompanyDefaultsSeeder.SeedAsync(_db, newEntity.Id);
            await tx.CommitAsync();
        });

        // Provision the SaaS control-plane Tenant (+ trial subscription) in the
        // Master DB. NON-FATAL and OUTSIDE the tenant-data transaction (separate
        // database): a Master-DB outage must never fail company creation. It's
        // idempotent, so it can be re-run later (e.g. via /Master/Provision).
        try
        {
            await _provisioning.ProvisionTenantAsync(
                newEntity.Id,
                newEntity.Name,
                seatAllowance: req.SeatAllowance ?? DefaultTrialSeats,
                subscriptionDays: req.SubscriptionDays ?? DefaultTrialDays);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Company {CompanyId} created but Master-DB tenant provisioning failed — retry later.",
                newEntity.Id);
        }

        return  new CompanyDto
        {
            Id = newEntity.Id,
            Name = newEntity.Name,
            CountryName = (await _countryRepository.GetCountryIdQuery(newEntity.CountryId))?.Name,
            Address = newEntity.Address,
            PostalCode = newEntity.PostalCode,
            City = newEntity.City,
            TaxNumber = newEntity.TaxNumber,
            Email = newEntity.Email,
            PhoneNumber = newEntity.PhoneNumber,
            BankAccountNumber = newEntity.BankAccountNumber,
            BankDetails = newEntity.BankDetails,
            StreetName = newEntity.StreetName,
            AdditionalStreetName = newEntity.AdditionalStreetName,
            BuildingNumber = newEntity.BuildingNumber,
            PlotIdentification = newEntity.PlotIdentification,
            CitySubdivisionName = newEntity.CitySubdivisionName,
            CountrySubentity = newEntity.CountrySubentity
        };
    }

    public async Task<CompanyDto> Update_DetailsAsync(UpdateCompanyRequest req)
    {
        var entityToUpdate = await _companyRepository.GetByIdAsync(req.Id);
        if (entityToUpdate == null)
            throw new InvalidOperationException($"A Company with the ID '{req.Id}' does not exist.");
        var existingName = await _companyRepository.GetByNameAsync(req.Name);
        if (existingName != null && existingName.Id != req.Id)
            throw new InvalidOperationException($"A Company with the name '{req.Name}' already exists.");
        entityToUpdate.UpdateDetails(
            req.Name, 
            req.CountryId,
            req.Address ?? entityToUpdate.Address,
            req.PostalCode ?? entityToUpdate.PostalCode,
            req.City ?? entityToUpdate.City,
            req.TaxNumber ?? entityToUpdate.TaxNumber,
            req.Email ?? entityToUpdate.Email,
            req.PhoneNumber ?? entityToUpdate.PhoneNumber,
            req.BankAccountNumber ?? entityToUpdate.BankAccountNumber,
            req.BankDetails ?? entityToUpdate.BankDetails,
            req.StreetName ?? entityToUpdate.StreetName,
            req.AdditionalStreetName ?? entityToUpdate.AdditionalStreetName,
            req.BuildingNumber ?? entityToUpdate.BuildingNumber,
            req.PlotIdentification ?? entityToUpdate.PlotIdentification,
            req.CitySubdivisionName ?? entityToUpdate.CitySubdivisionName,
            req.CountrySubentity ?? entityToUpdate.CountrySubentity
        );

        await _companyRepository.UpdateAsync(entityToUpdate);

        return new CompanyDto
        {
            Id = entityToUpdate.Id,
            Name = entityToUpdate.Name,
            CountryName = (await _countryRepository.GetCountryIdQuery(entityToUpdate.CountryId))?.Name,
            Address = entityToUpdate.Address,
            PostalCode = entityToUpdate.PostalCode,
            City = entityToUpdate.City,
            TaxNumber = entityToUpdate.TaxNumber,
            Email = entityToUpdate.Email,
            PhoneNumber = entityToUpdate.PhoneNumber,
            BankAccountNumber = entityToUpdate.BankAccountNumber,
            BankDetails = entityToUpdate.BankDetails,
            StreetName = entityToUpdate.StreetName,
            AdditionalStreetName = entityToUpdate.AdditionalStreetName,
            BuildingNumber = entityToUpdate.BuildingNumber,
            PlotIdentification = entityToUpdate.PlotIdentification,
            CitySubdivisionName = entityToUpdate.CitySubdivisionName,
            CountrySubentity = entityToUpdate.CountrySubentity
        };
    }
    public async Task<bool> Update_LogoAsync(UpdateCompanyLogoRequest req)
    {
        var entityToUpdate = await _companyRepository.GetByIdAsync(req.Id);
        if (entityToUpdate == null)
            throw new InvalidOperationException($"A Company with the ID '{req.Id}' does not exist.");
        entityToUpdate.UpdateLogo(req.Logo);
        await _companyRepository.UpdateAsync(entityToUpdate);
        return true;
    }

    /// <summary>
    /// Clears the company logo.
    ///
    /// Its own operation rather than an empty <see cref="Update_LogoAsync"/>:
    /// that request validates Logo as NotNull().NotEmpty(), and relaxing it so
    /// "empty means delete" would turn a truncated upload into a silent wipe of
    /// the logo. Deleting is a thing you ask for, never something an upload
    /// falls into.
    /// </summary>
    public async Task<bool> Delete_LogoAsync(int id)
    {
        var entityToUpdate = await _companyRepository.GetByIdAsync(id);
        if (entityToUpdate == null)
            throw new InvalidOperationException($"A Company with the ID '{id}' does not exist.");
        entityToUpdate.UpdateLogo(null);
        await _companyRepository.UpdateAsync(entityToUpdate);
        return true;
    }

    /// <summary>
    /// Deletes a company and ALL of its data. The schema has ~40 child tables
    /// referencing Company with no cascade, so a plain delete fails on the first
    /// FK. This purges every CompanyId-scoped row for the company in one
    /// transaction, in foreign-key dependency order — children before parents —
    /// so constraint enforcement stays ON throughout.
    ///
    /// Only CompanyId-scoped tables are touched. Global reference tables
    /// (Country, Currency, DocumentType, DocumentCategory — none of which have a
    /// CompanyId column) are never in the set, so deleting a company can never
    /// reach global data.
    ///
    /// 🚨 This used to disable every constraint, delete in arbitrary order, then
    /// re-arm WITH CHECK. Do not reintroduce that: it needs ALTER on ~50 tables,
    /// and the production API login is only db_datareader + db_datawriter, so
    /// the toggle fails with "Cannot find the object … or you do not have
    /// permissions." See <see cref="ForeignKeyDeleteOrder"/>.
    /// </summary>
    public async Task<bool> DeleteAsync(int id)
    {
        var entityToDelete = await _companyRepository.GetByIdAsync(id);
        if (entityToDelete == null)
            throw new InvalidOperationException($"A Company with the ID '{id}' does not exist.");

        var deleteStrategy = _db.Database.CreateExecutionStrategy();
        await deleteStrategy.ExecuteAsync(async () =>
        {
            await using var tx = await _db.Database.BeginTransactionAsync();

            // ZReportPaymentSummary has no CompanyId of its own, so it is not in
            // the ordered set below — it has to be purged up front, by following
            // its foreign keys back to the company.
            //
            // BOTH keys, not just ZReportId: the table also references
            // PaymentType, which is company-scoped and therefore deleted below.
            // Filtering on ZReportId alone leaves any row whose ZReport belongs
            // elsewhere but whose PaymentType is this company's, and that row
            // then blocks the PaymentType delete with
            // FK_ZReportPaymentSummary_PaymentType_PaymentTypeId. The old
            // constraints-off purge could not hit this — it simply orphaned the
            // row instead, and the WITH CHECK re-enable failed later, further
            // from the cause.
            await _db.Database.ExecuteSqlRawAsync(
                "DELETE FROM dbo.ZReportPaymentSummary " +
                "WHERE ZReportId IN (SELECT Id FROM dbo.ZReport WHERE CompanyId = @cid) " +
                "   OR PaymentTypeId IN (SELECT Id FROM dbo.PaymentType WHERE CompanyId = @cid);",
                new SqlParameter("@cid", id));

            // Every CompanyId-scoped table except Company itself, which is
            // deleted last and separately (it is the parent of all of them).
            var scoped = await _db.Database
                .SqlQueryRaw<string>(@"
                    SELECT t.name AS Value
                    FROM sys.tables t
                    WHERE EXISTS (SELECT 1 FROM sys.columns c
                                  WHERE c.object_id = t.object_id AND c.name = 'CompanyId')
                      AND t.name <> 'Company';")
                .ToListAsync();

            // Children before parents, so each DELETE only ever removes rows
            // nothing still points at and FK enforcement never has to be lifted.
            var ordered = await ForeignKeyDeleteOrder.ResolveAsync(_db.Database, scoped);

            foreach (var table in ordered)
            {
                ForeignKeyDeleteOrder.AssertSafeIdentifier(table);
#pragma warning disable EF1002 // identifier validated by AssertSafeIdentifier; the id stays a parameter
                await _db.Database.ExecuteSqlRawAsync(
                    $"DELETE FROM dbo.[{table}] WHERE CompanyId = @cid;",
                    new SqlParameter("@cid", id));
#pragma warning restore EF1002
            }

            await _db.Database.ExecuteSqlRawAsync(
                "DELETE FROM dbo.Company WHERE Id = @cid;",
                new SqlParameter("@cid", id));

            await tx.CommitAsync();
        });

        // Also remove the company's SaaS control-plane tenant. This lives in a
        // SEPARATE database (web-pos-master), so it cannot join the transaction
        // above and a Master-DB outage must not fail the company delete.
        //
        // 🚨 It used to be swallowed into a LogWarning while the admin portal
        // still reported "Company and all its data were deleted." — so a failure
        // here left the Tenant, its Subscription, its DeviceRegistry seats and
        // its Pillar-5 audit rows alive, with nothing on screen to say so. That
        // is the "deleted a company but it didn't delete all its data" report.
        // The tenant-data purge above has already committed and is not undone;
        // the caller is told exactly what remains so it can be retried.
        try
        {
            await _provisioning.DeprovisionTenantAsync(id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Company {CompanyId} data was deleted, but Master-DB tenant removal failed.", id);
            throw new CompanyPartiallyDeletedException(id, ex);
        }

        return true;
    }
}

/// The company's own data was deleted, but its SaaS control-plane tenant
/// (Master DB: Tenant + Subscription + DeviceRegistry + TransactionAudit)
/// was not. Distinct from a plain failure because the tenant-data purge has
/// already COMMITTED — retrying the delete will report "does not exist", so the
/// operator must clear the tenant separately (or re-run once the Master DB is
/// reachable). Surfaced so the admin portal stops claiming a clean delete.
public class CompanyPartiallyDeletedException : Exception
{
    public int CompanyId { get; }

    public CompanyPartiallyDeletedException(int companyId, Exception inner)
        : base($"Company {companyId}'s data was deleted, but its licensing tenant " +
               "could not be removed from the Master database. The tenant, its " +
               "subscription and its device seats still exist — clear them once " +
               "the Master database is reachable.", inner)
    {
        CompanyId = companyId;
    }
}
