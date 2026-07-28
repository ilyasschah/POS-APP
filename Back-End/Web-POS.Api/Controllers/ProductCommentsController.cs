using MediatR;
using Microsoft.AspNetCore.Mvc;
using Api.Commands.ProductsCommentsCommands.Add;
using Api.Commands.ProductsCommentsCommands.Delete;
using Api.Commands.ProductsCommentsCommands.Update;
using Api.Queries.ProductCommentsQuery;
using Api.Models;

namespace Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductCommentsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductCommentDto>>> GetAll([FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });

            var result = await mediator.Send(new GetAllProductCommentsQuery { CompanyId = companyId }, ct);
            return Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<ProductCommentDto>> GetById([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (id <= 0) return BadRequest(new { message = "Comment ID is required" });

            var result = await mediator.Send(new GetProductCommentByIdQuery { Id = id, CompanyId = companyId }, ct);
            return result is null ? NotFound(new { message = "Product comment not found" }) : Ok(result);
        }

        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductCommentDto>>> GetByProductId([FromQuery] int productId, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (productId <= 0) return BadRequest(new { message = "Product ID is required" });

            var result = await mediator.Send(new GetProductCommentsByProductIdQuery { ProductId = productId, CompanyId = companyId }, ct);
            return Ok(result);
        }

        [HttpPost("[action]")]
        public async Task<ActionResult<ProductCommentDto>> Add([FromBody] CreateProductCommentRequest req, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            try
            {
                var result = await mediator.Send(new AddProductCommentCommand(req, companyId), ct);

                return Ok(result);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpPatch("[action]")]
        public async Task<IActionResult> Update([FromBody] UpdateProductCommentRequest req, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            try
            {
                var ok = await mediator.Send(new UpdateProductCommentCommand(req, companyId), ct);
                return ok
                    ? Ok(new { message = "Product comment updated successfully" })
                    : NotFound(new { message = "Product comment not found" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        [HttpDelete("[action]")]
        public async Task<IActionResult> Delete([FromQuery] int id, [FromQuery] int companyId, CancellationToken ct = default)
        {
            if (companyId <= 0) return BadRequest(new { message = "Company ID is required" });
            if (id <= 0) return BadRequest(new { message = "Comment ID is required" });
            try
            {
                var ok = await mediator.Send(new DeleteProductCommentCommand(id, companyId), ct);
                return ok
                    ? Ok(new { message = "Product comment deleted successfully" })
                    : NotFound(new { message = "Product comment not found" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}