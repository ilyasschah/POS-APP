using FluentValidation;
using MediatR;
using Api.Helpers;
using Api.Models;
using Api.Services;

namespace Api.Commands.ProductsCommentsCommands.Add
{
    public class AddProductCommentCommand : IRequest<ProductCommentDto>
    {
        public CreateProductCommentRequest Request { get; }
        public int CompanyId { get; }

        public AddProductCommentCommand(CreateProductCommentRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddProductCommentCommandHandler : IRequestHandler<AddProductCommentCommand, ProductCommentDto>
        {
            private readonly ProductCommentService _service;

            public AddProductCommentCommandHandler(ProductCommentService service)
            {
                _service = service;
            }

            public async Task<ProductCommentDto> Handle(AddProductCommentCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.CreateAsync(command.Request, command.CompanyId);
                return MapperProductComment.MapToProductCommentDto(entity);
            }
        }

        public class AddProductCommentCommandValidator : AbstractValidator<AddProductCommentCommand>
        {
            public AddProductCommentCommandValidator()
            {
                RuleFor(x => x.Request.ProductId).GreaterThan(0).WithMessage("Product ID must be valid.");
                RuleFor(x => x.Request.Comment).NotEmpty().WithMessage("Comment cannot be empty.");
                RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}
