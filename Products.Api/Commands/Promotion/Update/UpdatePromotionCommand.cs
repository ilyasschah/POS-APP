using FluentValidation;
using MediatR;
using Products.Api.Models;
using Products.Api.Services;
using System.Threading;
using System.Threading.Tasks;

namespace Products.Api.Commands.Promotion.Update
{
    public class UpdatePromotionCommand : IRequest<bool>
    {
        public int Id { get; }
        public UpdatePromotionRequest Request { get; }

        public UpdatePromotionCommand(int id, UpdatePromotionRequest request)
        {
            Id = id;
            Request = request;
        }

        public class UpdatePromotionCommandHandler : IRequestHandler<UpdatePromotionCommand, bool>
        {
            private readonly PromotionService _service;

            public UpdatePromotionCommandHandler(PromotionService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdatePromotionCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Id, command.Request);
            }
        }

        public class UpdatePromotionCommandValidator : AbstractValidator<UpdatePromotionCommand>
        {
            public UpdatePromotionCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0);
                RuleFor(c => c.Request.Name).NotEmpty();
            }
        }
    }
}