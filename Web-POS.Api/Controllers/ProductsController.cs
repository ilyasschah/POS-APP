using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Attributes;
using Api.Commands.ProductCommands.Add;
using Api.Commands.ProductCommands.Delete;
using Api.Commands.ProductCommands.Import;
using Api.Commands.ProductCommands.Update;
using Api.Queries.ProductsQuery;
using Api.Models;

namespace Api.Controllers
{
    [SwaggerVisible]
    [ApiController]
    [Route("api/[controller]")]
    public class ProductsController(IMediator mediator) : ControllerBase
    {

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductDto>>> GetAll([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            var result = await mediator.Send(new GetAllProductsQuery { CompanyId = companyId });
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<ProductDto>> GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            var result = await mediator.Send(new GetProductByIdQuery { Id = id, CompanyId = companyId });
            return result is null ? NotFound(new { message = "Product not found" }) : Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductDto>>> GetByProductGroup([FromQuery] int productGroupId, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            var result = await mediator.Send(new GetProductGroupQuery { ProductGroup = productGroupId, CompanyId = companyId });
            return result is null ? NotFound(new { message = "No products found for this group" }) : Ok(result);
        }


        [HttpPost("[action]")]
        public async Task<ActionResult<ImportProductsResult>> ImportBulk([FromBody] ImportProductsRequest req)
        {
            if (req.CompanyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (req.Rows == null || req.Rows.Count == 0)
                return BadRequest(new { message = "No rows to import" });
            var result = await mediator.Send(new ImportProductsCommand(req));
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductExportDto>>> GetForExport([FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            var result = await mediator.Send(new GetProductsForExportQuery { CompanyId = companyId });
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<ProductDto>> Add([FromBody] CreateProductRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var command = new AddProductCommand(req, companyId);
                var result = await mediator.Send(command);

                return Ok(new { message = "Product created successfully", data = result });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpPatch("[action]")] 
        public async Task<IActionResult> Update([FromBody] UpdateProductRequest req, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var ok = await mediator.Send(new UpdateProductCommand(req, companyId));
                return ok ? Ok(new { message = "Product updated successfully" }) : NotFound(new { message = "Product not found" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            try
            {
                var ok = await mediator.Send(new DeleteProductCommand(id, companyId));
                return ok ? Ok(new { message = "Product deleted successfully" }) : NotFound(new { message = "Product not found" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}