using Api.Domain;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class TaxService
    {
        private readonly TaxRepository _repository;
        public readonly CompanyRepository _companyRepository;

        public TaxService(TaxRepository repository, CompanyRepository companyRepository)
        {
            _repository = repository;
            _companyRepository = companyRepository;
        }

        public async Task<TaxDto> CreateAsync(CreateTaxRequestDto req, int companyId)
        {
            var existingTax = await _repository.GetByNameAsync(req.Name, companyId);
            if (existingTax != null)
                throw new InvalidOperationException($"A Tax with the name '{req.Name}' already exists for your company.");

            // The DB enforces UQ_Tax_Code_PerCompany on (CompanyId, Code), and an
            // EMPTY code counts as a value there — so a second code-less tax hit
            // SQL error 2601 and surfaced as an unhandled 500 (the whole reason
            // this check exists). Catch it here and report it as a 400, per the
            // graceful-errors rule.
            var codeClash = await _repository.GetByCodeAsync(req.Code, companyId);
            if (codeClash != null)
                throw new InvalidOperationException(
                    string.IsNullOrWhiteSpace(req.Code)
                        ? $"Tax '{codeClash.Name}' already has no code, and codes must be unique. Give this tax a code."
                        : $"A Tax with the code '{req.Code}' already exists for your company.");

           var newTax = Tax.Create(
                companyId, 
                req.Name,
                req.Rate,
                req.Code,
                req.IsFixed,
                req.IsTaxOnTotal,
                req.IsEnabled
            );

            await _repository.AddTaxAsync(newTax);
            return new TaxDto
            {
                Id = newTax.Id,
                Name = newTax.Name,
                Rate = newTax.Rate,
                Code = newTax.Code,
                IsFixed = newTax.IsFixed,
                IsTaxOnTotal = newTax.IsTaxOnTotal,
                IsEnabled = newTax.IsEnabled,
                CompanyId = companyId

            };
        }

        public async Task<bool> UpdateAsync(UpdateTaxRequestDto req, int companyId)
        {
            var entity = await _repository.GetTaxByIdAsync(req.Id, companyId);
            if (entity == null)
                throw new InvalidOperationException($"Tax with ID '{req.Id}' not found.");
            if (req.Name != null)
            {
                var conflict = await _repository.GetByNameAsync(req.Name, companyId);
                if (conflict != null && conflict.Id != req.Id)
                    throw new InvalidOperationException($"Another Tax with the name '{req.Name}' already exists.");
            }

            // Same UQ_Tax_Code_PerCompany guard as CreateAsync — an edit that
            // moves a tax onto a code (or onto "no code") another tax already
            // holds would 500 exactly the same way. Only checked when the
            // request actually carries a Code; null means "leave it alone".
            if (req.Code != null)
            {
                var codeClash = await _repository.GetByCodeAsync(req.Code, companyId);
                if (codeClash != null && codeClash.Id != req.Id)
                    throw new InvalidOperationException(
                        string.IsNullOrWhiteSpace(req.Code)
                            ? $"Tax '{codeClash.Name}' already has no code, and codes must be unique. Give this tax a code."
                            : $"Another Tax with the code '{req.Code}' already exists.");
            }

            entity.Name = req.Name ?? entity.Name;
            entity.Rate = req.Rate ?? entity.Rate;
            // Trimmed on the way in, exactly as Tax.Create does it — the
            // uniqueness lookup above compares trimmed values, so storing an
            // untrimmed one would let " 20" slip past a check that read it
            // as "20".
            entity.Code = req.Code?.Trim() ?? entity.Code;
            entity.IsFixed = req.IsFixed ?? entity.IsFixed;
            entity.IsTaxOnTotal = req.IsTaxOnTotal ?? entity.IsTaxOnTotal;
            entity.IsEnabled = req.IsEnabled ?? entity.IsEnabled;

            await _repository.UpdateTaxAsync(entity);
            return true;
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var taxToDelete = await _repository.GetTaxByIdAsync(id, companyId);
            if (taxToDelete == null) return false;

            // Checked up front rather than left to the FK constraints. The
            // constraint did refuse — but as a DbUpdateException, logged as an EF
            // failure with a full stack trace, and answered with a generic "still
            // referenced by other data" that named neither the tax nor the cause.
            // History blocks the delete for good; product links only until the
            // products are moved to another tax.
            var (products, saleLines) = await _repository.GetUsageAsync(taxToDelete.Id);
            if (saleLines > 0)
                throw new InvalidOperationException(
                    $"Tax '{taxToDelete.Name}' can't be deleted: it appears in {saleLines} sale or document line(s), which must keep the tax they were issued with. Disable it instead.");
            if (products > 0)
                throw new InvalidOperationException(
                    $"Tax '{taxToDelete.Name}' can't be deleted: {products} product(s) use it. Move them to another tax first (Switch Taxes), or disable this tax instead.");

            await _repository.DeleteTaxAsync(taxToDelete.Id, companyId);
            return true;
        }
    }
}