using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Attributes;
using Api.Commands.ProductCommands.Add;
using Api.Commands.ProductCommands.Delete;
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
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetAllProductsQuery { CompanyId = companyId });
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<ProductDto>>GetById([FromQuery] int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetProductByIdQuery { Id = id, CompanyId = companyId });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<ProductDto>> GetByProductGroup([FromQuery] int productGroupId, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetProductByProductGroupQuery { ProductGroup = productGroupId, CompanyId = companyId });
            return result is null ? NotFound() : Ok(result);
        }


        [HttpPost("[action]")]
        public async Task<ActionResult<ProductDto>> Add([FromBody] CreateProductRequest req,[FromQuery] int companyId)           
        {
            if (companyId <= 0) return BadRequest("Company ID is required");

            var command = new AddProductCommand(req, companyId);
            command.Request.CompanyId = companyId;

            var result = await mediator.Send(command);
            return CreatedAtAction(nameof(GetById), new { id = result.Id, companyId }, result);
        }

        [HttpPut("[action]")]
        public async Task<IActionResult> Update([FromQuery] int id,[FromBody] UpdateProductRequest req,[FromQuery] int companyId)          
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var ok = await mediator.Send(new UpdateProductCommand(id, req, companyId));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id,[FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var ok = await mediator.Send(new DeleteProductCommand(id, companyId));
            return ok ? NoContent() : NotFound();
        }
    }
}