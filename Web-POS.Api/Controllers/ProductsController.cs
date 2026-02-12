using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.ProductCommands.Add;
using Products.Api.Commands.ProductCommands.Delete;
using Products.Api.Commands.ProductCommands.Update;
using Products.Api.Models;
using Products.Api.Queries.ProductsQuery;

namespace Products.Api.Controllers
{
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

        [HttpGet("[action]/{id:int}")]
        public async Task<ActionResult<ProductDto>>GetById(int id, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetProductByIdQuery { Id = id, CompanyId = companyId });
            return result is null ? NotFound() : Ok(result);
        }

        [HttpGet("[action]/{code}")]
        public async Task<ActionResult<ProductDto>> GetByCode(string code, [FromQuery] int companyId)
        {
            if (companyId <= 0) return BadRequest("Company ID is required");
            var result = await mediator.Send(new GetProductByCodeQuery { Code = code, CompanyId = companyId });
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

        [HttpPut("[action]/{id:int}")]
        public async Task<IActionResult> Update(int id,[FromBody] UpdateProductRequest req,[FromQuery] int companyId)          
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var ok = await mediator.Send(new UpdateProductCommand(id, req, companyId));
            return ok ? NoContent() : NotFound();
        }

        [HttpDelete("[action]/{id:int}")]
        public async Task<IActionResult> Delete(int id,[FromQuery] int companyId)
        {
            if (companyId == 0) return BadRequest("Company ID is required");
            var ok = await mediator.Send(new DeleteProductCommand(id, companyId));
            return ok ? NoContent() : NotFound();
        }
    }
}