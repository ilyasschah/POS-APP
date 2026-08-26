using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Attributes;
using Api.Commands.CompanyCommands.Add;
using Api.Commands.CompanyCommands.Delete;
using Api.Commands.CompanyCommands.Update;
using Api.Queries.CompanyQuery;
using Api.Models;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class CompanyController(IMediator mediator) : ControllerBase
    {
        /// <summary>
        /// Every company on the account. ⚠️ Left OUT of the tenant filter on
        /// purpose: master login lists the companies a terminal may sign in to,
        /// and it runs before a company has been chosen, so scoping it to the
        /// caller's current company would empty the picker. It carries no
        /// companyId to check in any case. Narrowing this to the companies the
        /// signed-in ACCOUNT owns is a real improvement and a separate change.
        /// </summary>
        [AllowCrossCompany]
        [HttpGet("[action]")]
        public async Task<ActionResult<List<CompanyDto>>> GetAll(CancellationToken ct = default)
        {
            var companies = await mediator.Send(new GetAllCompaniesQuery(), ct);
            return Ok(companies);
        }
        // `id` here IS the company id. Named so, it is invisible to the tenant
        // filter, which looks for `companyId` — everywhere else in this API a bare
        // `id` is a product, a document or a user.
        [CompanyScopedBy("id")]
        [HttpGet("[action]")]
        public async Task<ActionResult<CompanyDto>> GetById(int id, CancellationToken ct = default)
        {
            if (id <= 0) return BadRequest("Company ID is required");
            return Ok(await mediator.Send(new GetCompanyByIdQuery(id), ct));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<CompanyDto>> Create([FromBody] CreateCompanyRequest request, CancellationToken ct = default)
        {
            var command = new AddCompanyCommand(request);
            var createdCompany = await mediator.Send(command, ct);
            return Ok(new
            {
                message = $"Company '{createdCompany.Name}' created successfully.",
            });
        }
        [CompanyScopedBy("id")]
        [HttpPatch("[action]")]
        public async Task<ActionResult<CompanyDto>> Update([FromBody] UpdateCompanyRequest req, CancellationToken ct = default)
        {
            var command = new UpdateCompanyCommand(req);
            var result = await mediator.Send(command, ct);

            return Ok(result);
        }
        [CompanyScopedBy("id")]
        [HttpPut("[action]")]
        public async Task<ActionResult> UpdateLogo([FromBody] UpdateCompanyLogoRequest request, CancellationToken ct = default)
        {
            var command = new UpdateCompanyLogoCommand(request);
            await mediator.Send(command, ct);
            return Ok(new
            {
                message = "Company logo updated successfully.",
            });
        }
        [CompanyScopedBy("id")]
        [HttpDelete("[action]")]
        public async Task<ActionResult> Delete(int id, CancellationToken ct = default)
        {
            var command = new DeleteCompanyCommand(id);
            await mediator.Send(command, ct);
            return Ok(new
            {
                message = "Company deleted successfully.",
            });
        }

        /// <summary>
        /// Clears the selected data for a company across the WHOLE account —
        /// every terminal sees it on the next sync. Irreversible.
        ///
        /// The client authorises this against the signed-in admin's device PIN
        /// before calling, and takes a local .sqlite backup first; neither is
        /// something the server can verify, so this endpoint is deliberately
        /// explicit about what it is (POST ResetData, not a DELETE that could be
        /// stumbled into) and refuses an empty selection rather than treating it
        /// as "reset everything".
        /// </summary>
        [HttpPost("[action]")]
        public async Task<ActionResult> ResetData(
            [FromServices] Api.Services.CompanyDataResetService resetService,
            [FromBody] ResetCompanyDataRequest request,
            CancellationToken ct = default)
        {
            if (request.CompanyId <= 0)
                return BadRequest(new { success = false, message = "Company ID is required." });

            var options = new Api.Services.ResetCompanyDataOptions
            {
                Products = request.Products,
                Customers = request.Customers,
                Documents = request.Documents,
                Everything = request.Everything,
            };

            if (!options.Any)
                return BadRequest(new { success = false, message = "Select at least one thing to reset." });

            var result = await resetService.ResetAsync(request.CompanyId, options);
            return Ok(new
            {
                success = true,
                message = $"Reset {result.RowsDeleted} row(s) across {result.TablesCleared.Count} table(s).",
                tablesCleared = result.TablesCleared,
                rowsDeleted = result.RowsDeleted,
            });
        }
    }
}