using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.ProductGroupCommands.Update
{
    public class UpdateProductGroupCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdateProductGroupRequest Request { get; }

        public UpdateProductGroupCommand(int id, UpdateProductGroupRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdateProductGroupCommandHandler : IRequestHandler<UpdateProductGroupCommand, bool>
        {
            private readonly ProductGroupService _service;

            public UpdateProductGroupCommandHandler(ProductGroupService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateProductGroupCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdateProductGroupCommandValidator : AbstractValidator<UpdateProductGroupCommand>
        {
            public UpdateProductGroupCommandValidator()
            {
                RuleFor(x => x.Id).GreaterThan(0);
                RuleFor(x => x.Request.Name).NotEmpty().MaximumLength(255);
                RuleFor(x => x.Request.Color).NotEmpty().MaximumLength(50);
                RuleFor(x => x.Request.Rank).GreaterThanOrEqualTo(0);
                RuleFor(x => x.Request.ParentGroupId).GreaterThan(0).When(x => x.Request.ParentGroupId.HasValue);
            }
        }
    }
}
