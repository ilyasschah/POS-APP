using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.ProductTaxCommands.Add;
using Api.Commands.ProductTaxCommands.Delete;
using Api.Queries.ProductTaxQuery;
using Api.Models;
using Api.Attributes;

namespace Api.Controllers
{
    //[SwaggerVisible]
    [Route("api/[controller]")]
    [ApiController]
    public class ProductTaxesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductTaxDto>>> GetAll([FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            return Ok(await mediator.Send(new GetAllProductTaxesQuery { CompanyId = companyId }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductTaxDto>>> GetByProductId([FromQuery] int productId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            return Ok(await mediator.Send(new GetProductTaxesByProductIdQuery { ProductId = productId, CompanyId = companyId }, ct));
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductTaxDto>>> GetByTaxId([FromQuery] int taxId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            return Ok(await mediator.Send(new GetProductTaxesByTaxIdQuery { TaxId = taxId, CompanyId = companyId }, ct));
        }

        [HttpPost("[action]")]
        public async Task<IActionResult> Add([FromBody] CreateProductTaxRequest request, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                await mediator.Send(new AddProductTaxCommand { Request = request, CompanyId = companyId }, ct);
                return Ok(new { message = "Tax linked successfully" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int productId, [FromQuery] int taxId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            var ok = await mediator.Send(new DeleteProductTaxCommand { ProductId = productId, TaxId = taxId, CompanyId = companyId }, ct);
            return ok ? Ok(new { message = "Tax unlinked successfully" }) : NotFound(new { message = "Link not found" });
        }
    }
}